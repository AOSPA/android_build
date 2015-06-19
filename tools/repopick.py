#!/usr/bin/env python
#
# Copyright (C) 2013 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Run repopick.py -h for a description of this utility.
#

from __future__ import print_function

import sys
import json
import os
import subprocess
import re
import argparse
import textwrap

try:
  # For python3
  import urllib.error
  import urllib.request
except ImportError:
  # For python2
  import imp
  import urllib2
  urllib = imp.new_module('urllib')
  urllib.error = urllib2
  urllib.request = urllib2

# Parse the command line
parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, description=textwrap.dedent('''\
    repopick.py is a utility to simplify the process of cherry picking
    patches from ParanoidAndroid Legacy's Gerrit instance.

    Given a list of change numbers, repopick will cd into the project path
    and cherry pick the latest patch available.

    With the --start-branch argument, the user can specify that a branch
    should be created before cherry picking. This is useful for
    cherry-picking many patches into a common branch which can be easily
    abandoned later (good for testing other's changes.)

    The --abandon-first argument, when used in conjuction with the
    --start-branch option, will cause repopick to abandon the specified
    branch in all repos first before performing any cherry picks.'''))
parser.add_argument('change_number', nargs='*', help='change number to cherry pick')
parser.add_argument('-i', '--ignore-missing', action='store_true', help='do not error out if a patch applies to a missing directory')
parser.add_argument('-c', '--checkout', action='store_true', help='checkout instead of cherry pick')
parser.add_argument('-s', '--start-branch', nargs=1, help='start the specified branch before cherry picking')
parser.add_argument('-a', '--abandon-first', action='store_true', help='before cherry picking, abandon the branch specified in --start-branch')
parser.add_argument('-b', '--auto-branch', action='store_true', help='shortcut to "--start-branch auto --abandon-first --ignore-missing"')
parser.add_argument('-q', '--quiet', action='store_true', help='print as little as possible')
parser.add_argument('-v', '--verbose', action='store_true', help='print extra information to aid in debug')
parser.add_argument('-t', '--topic', help='pick all commits from a specified topic')
parser.add_argument('-Q', '--query', help='pick all commits using the specified query')
args = parser.parse_args()
if args.start_branch == None and args.abandon_first:
    parser.error('if --abandon-first is set, you must also give the branch name with --start-branch')
if args.auto_branch:
    args.abandon_first = True
    args.ignore_missing = True
    if not args.start_branch:
        args.start_branch = ['auto']
if args.quiet and args.verbose:
    parser.error('--quiet and --verbose cannot be specified together')
if len(args.change_number) > 0:
    if args.topic or args.query:
        parser.error('cannot specify a topic (or query) and change number(s) together')
if args.topic and args.query:
    parser.error('cannot specify a topic and a query together')
if len(args.change_number) == 0 and not args.topic and not args.query:
    parser.error('must specify at least one commit id or a topic or a query')

# Helper function to determine whether a path is an executable file
def is_exe(fpath):
    return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

# Implementation of Unix 'which' in Python
#
# From: http://stackoverflow.com/questions/377017/test-if-executable-exists-in-python
def which(program):
    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file
    sys.stderr.write('ERROR: Could not find the %s program in $PATH\n' % program)
    sys.exit(1)

# Simple wrapper for os.system() that:
#   - exits on error
#   - prints out the command if --verbose
#   - suppresses all output if --quiet
def execute_cmd(cmd, exit_on_fail=True):
    if args.verbose:
        print('Executing: %s' % cmd)
    #if args.quiet:
    #    cmd = cmd.replace(' && ', ' &> /dev/null && ')
    #    cmd = cmd + " &> /dev/null"
    ret = os.system(cmd)
    if ret and exit_on_fail:
        if not args.verbose:
            sys.stderr.write('\nERROR: Command that failed:\n%s' % cmd)
        sys.exit(1)
    return ret

# Verifies whether pathA is a subdirectory (or the same) as pathB
def is_pathA_subdir_of_pathB(pathA, pathB):
    pathA = os.path.realpath(pathA) + '/'
    pathB = os.path.realpath(pathB) + '/'
    return(pathB == pathA[:len(pathB)])

# Find the necessary bins - repo
repo_bin = which('repo')

# Find the necessary bins - git
git_bin = which('git')

# Change current directory to the top of the tree
if 'ANDROID_BUILD_TOP' in os.environ:
    top = os.environ['ANDROID_BUILD_TOP']
    if not is_pathA_subdir_of_pathB(os.getcwd(), top):
        sys.stderr.write('ERROR: You must run this tool from within $ANDROID_BUILD_TOP!\n')
        sys.exit(1)
    os.chdir(os.environ['ANDROID_BUILD_TOP'])

# Sanity check that we are being run from the top level of the tree
if not os.path.isdir('.repo'):
    sys.stderr.write('ERROR: No .repo directory found. Please run this from the top of your tree.\n')
    sys.exit(1)

# If --abandon-first is given, abandon the branch before starting
if args.abandon_first:
    # Determine if the branch already exists; skip the abandon if it does not
    plist = subprocess.Popen([repo_bin,"info"], stdout=subprocess.PIPE)
    needs_abandon = False
    while(True):
        pline = plist.stdout.readline().rstrip()
        if not pline:
            break
        matchObj = re.match(r'Local Branches.*\[(.*)\]', pline.decode())
        if matchObj:
            local_branches = re.split('\s*,\s*', matchObj.group(1))
            if any(args.start_branch[0] in s for s in local_branches):
                needs_abandon = True

    if needs_abandon:
        # Perform the abandon only if the branch already exists
        if not args.quiet:
            print('Abandoning branch: %s' % args.start_branch[0])
        cmd = '%s abandon %s' % (repo_bin, args.start_branch[0])
        execute_cmd(cmd)
        if not args.quiet:
            print('')

# Get the list of projects that repo knows about
#   - convert the project name to a project path
project_name_to_path = {}
plist = subprocess.Popen([repo_bin,"list"], stdout=subprocess.PIPE)
project_path = None
while(True):
    pline = plist.stdout.readline().rstrip()
    if not pline:
        break
    ppaths = re.split('\s*:\s*', pline.decode())
    project_name_to_path[ppaths[1]] = ppaths[0]

# Get all commits for a specified query
def fetch_query(query):
    url = 'http://gerrit.aospal.com/changes/?q=%s' % query
    if args.verbose:
        print('Fetching all commits using query: %s\n' % query)
    f = urllib.request.urlopen(url)
    d = f.read().decode("utf-8")
    if args.verbose:
        print('Result from request:\n' + d)

    # Clean up the result
    d = d.split(')]}\'\n')[1]
    matchObj = re.match(r'\[\s*\]', d)
    if matchObj:
        sys.stderr.write('ERROR: Query %s was not found on the server\n' % query)
        sys.exit(1)
    d = re.sub(r'\[(.*)\]', r'\1', d)
    if args.verbose:
        print('Result from request:\n' + d)

    data = json.loads(d)
    changelist = []
    for c in xrange(0, len(data)):
        changelist.append(data[c]['_number'])

    # Reverse the array as we want to pick the lowest one first
    args.change_number = reversed(changelist)

if args.topic:
    fetch_query("topic:{0}".format(args.topic))

if args.query:
    fetch_query(args.query)

# Check for range of commits and rebuild array
changelist = []
for change in args.change_number:
    c=str(change)
    if '-' in c:
        templist = c.split('-')
        for i in range(int(templist[0]), int(templist[1]) + 1):
            changelist.append(str(i))
    else:
        changelist.append(c)

args.change_number = changelist

# Iterate through the requested change numbers
for change in args.change_number:
    if not args.quiet:
        print('Applying change number %s ...' % change)

    # Fetch information about the change from Gerrit's REST API
    #
    # gerrit returns two lines, a magic string and then valid JSON:
    #   )]}'
    #   [ ... valid JSON ... ]
    url = 'http://gerrit.aospal.com/changes/?q=%s&o=CURRENT_REVISION&o=CURRENT_COMMIT&pp=0' % change
    if args.verbose:
        print('Fetching from: %s\n' % url)
    try:
        f = urllib.request.urlopen(url)
    except urllib.error.URLError:
        sys.stderr.write('ERROR: Server reported an error, or cannot be reached\n')
        sys.exit(1)
    d = f.read().decode("utf-8")
    if args.verbose:
        print('Result from request:\n' + d)

    # Clean up the result
    d = d.split('\n')[1]
    matchObj = re.match(r'\[\s*\]', d)
    if matchObj:
        sys.stderr.write('ERROR: Change number %s was not found on the server\n' % change)
        sys.exit(1)

    # Parse the JSON
    try:
        data_array = json.loads(d)
    except ValueError:
        sys.stderr.write('ERROR: The response from the server could not be parsed properly\n')
        if args.verbose:
            sys.stderr.write('The malformed response was: %s\n' % d)
        sys.exit(1)
    # Enumerate through JSON response
    for (i, data) in enumerate(data_array):
        date_fluff       = '.000000000'
        project_name     = data['project']
        change_number    = data['_number']
        current_revision = data['revisions'][data['current_revision']]
        patch_number     = current_revision['_number']
        # Backwards compatibility
        if 'http' in current_revision['fetch']:
            fetch_url        = current_revision['fetch']['http']['url']
            fetch_ref        = current_revision['fetch']['http']['ref']
        else:
            fetch_url        = current_revision['fetch']['anonymous http']['url']
            fetch_ref        = current_revision['fetch']['anonymous http']['ref']
        author_name      = current_revision['commit']['author']['name']
        author_email     = current_revision['commit']['author']['email']
        author_date      = current_revision['commit']['author']['date'].replace(date_fluff, '')
        committer_name   = current_revision['commit']['committer']['name']
        committer_email  = current_revision['commit']['committer']['email']
        committer_date   = current_revision['commit']['committer']['date'].replace(date_fluff, '')
        subject          = current_revision['commit']['subject']

        # Convert the project name to a project path
        #   - check that the project path exists
        if project_name in project_name_to_path:
            project_path = project_name_to_path[project_name];
        elif args.ignore_missing:
            print('WARNING: Skipping %d since there is no project directory for: %s\n' % (change_number, project_name))
            continue;
        else:
            sys.stderr.write('ERROR: For %d, could not determine the project path for project %s\n' % (change_number, project_name))
            continue;

        # If --start-branch is given, create the branch (more than once per path is okay; repo ignores gracefully)
        if args.start_branch:
            cmd = '%s start %s %s' % (repo_bin, args.start_branch[0], project_path)
            execute_cmd(cmd)

        # Print out some useful info
        if not args.quiet:
            print('--> Subject:       "%s"' % subject)
            print('--> Project path:  %s' % project_path)
            print('--> Change number: %d (Patch Set %d)' % (change_number, patch_number))
            print('--> Author:        %s <%s> %s' % (author_name, author_email, author_date))
            print('--> Committer:     %s <%s> %s' % (committer_name, committer_email, committer_date))

        if args.verbose:
            print('Trying to fetch the change %d (Patch Set %d) from Gerrit')
        cmd = 'cd %s && git fetch %s %s' % (project_path, fetch_url, fetch_ref)
        execute_cmd(cmd)
        # Check if it worked
        FETCH_HEAD = '%s/.git/FETCH_HEAD' % project_path
        if os.stat(FETCH_HEAD).st_size == 0:
            # That didn't work, print error and exit
            sys.stderr.write('ERROR: Fetching change from Gerrit failed. Exiting...')
            continue;
        # Perform the cherry-pick or checkout
        if args.checkout:
            cmd = 'cd %s && git checkout FETCH_HEAD' % (project_path)
        else:
            cmd = 'cd %s && git cherry-pick FETCH_HEAD' % (project_path)

        execute_cmd(cmd)
        if not args.quiet:
            print('Change #%d (Patch Set %d) %s into %s' % (change_number, patch_number, 'checked out' if args.checkout else 'cherry-picked', project_path))