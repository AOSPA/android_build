#!/usr/bin/env python

# Copyright (C) 2013 Cybojenix <anthonydking@gmail.com>
# Copyright (C) 2013 The OmniROM Project
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

from __future__ import print_function
import json
import sys
import os
from xml.etree import ElementTree as ES
# Use the urllib importer from the Cyanogenmod roomservice
try:
    # For python3
    import urllib.request
except ImportError:
    # For python2
    import imp
    import urllib2
    urllib = imp.new_module('urllib')
    urllib.request = urllib2

# Config
# set this to the default remote to use in repo
default_rem = "github"
# set this to the default revision to use (branch/tag name)
default_rev = "android-4.3"
# set this to the remote that you use for projects from your team repos
# example fetch="https://github.com/omnirom"
default_team_rem = "omnirom"
# this shouldn't change unless google makes changes
local_manifest_dir = ".repo/local_manifests"
# change this to your name on github (or equivalent hosting)
android_team = "omnirom"


def check_repo_exists(git_data):
    if not int(git_data.get('total_count', 0)):
        raise Exception("{} not found in {} Github, exiting "
                        "roomservice".format(device, android_team))


# Note that this can only be done 5 times per minute
def search_github_for_device(device):
    git_search_url = "https://api.github.com/search/repositories" \
                     "?q=%40{}+android_device+{}".format(android_team, device)
    git_req = urllib.request.Request(git_search_url)
    try:
        response = urllib.request.urlopen(git_req)
    except urllib.request.HTTPError:
        raise Exception("There was an issue connecting to github."
                        " Please try again in a minute")
    git_data = json.load(response)
    check_repo_exists(git_data)
    print("found the {} device repo".format(device))
    return git_data


def get_device_url(git_data):
    device_url = ""
    for item in git_data['items']:
        temp_url = item.get('html_url')
        if "{}/android_device".format(android_team) in temp_url:
            try:
                temp_url = temp_url[temp_url.index("android_device"):]
            except ValueError:
                pass
            else:
                if temp_url.endswith(device):
                    device_url = temp_url
                    break

    if device_url:
        return device_url
    raise Exception("{} not found in {} Github, exiting "
                    "roomservice".format(device, android_team))


def parse_device_directory(device_url):
    to_strip = "android_device"
    repo_name = device_url[device_url.index(to_strip) + len(to_strip):]
    repo_dir = repo_name.replace("_", "/")
    return "device{}".format(repo_dir)


# Thank you RaYmAn
def iterate_manifests():
    files = []
    for file in os.listdir(local_manifest_dir):
        files.append(os.path.join(local_manifest_dir, file))
    files.append('.repo/manifest.xml')
    for file in files:
        try:
            man = ES.parse(file)
            man = man.getroot()
        except IOError, ES.ParseError:
            print("WARNING: error while parsing %s" % file)
        else:
            for project in man.findall("project"):
                yield project


def check_project_exists(url):
    for project in iterate_manifests():
        if project.get("name") == url:
            return True
    return False


# Use the indent function from http://stackoverflow.com/a/4590052
def indent(elem, level=0):
    i = ''.join(["\n", level*"  "])
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = ''.join([i, "  "])
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent(elem, level+1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i


def create_manifest_project(url, directory,
                            remote=default_rem,
                            revision=default_rev):
    project_exists = check_project_exists(url)

    if project_exists:
        return None

    project = ES.Element("project",
                         attrib={
                             "path": directory,
                             "name": url,
                             "remote": remote,
                             "revision": revision
                         })
    return project


def append_to_manifest(project):
    try:
        lm = ES.parse('/'.join([local_manifest_dir, "roomservice.xml"]))
        lm = lm.getroot()
    except IOError, ES.ParseError:
        lm = ES.Element("manifest")
    lm.append(project)
    return lm


def write_to_manifest(manifest):
    indent(manifest)
    raw_xml = ES.tostring(manifest).decode()
    raw_xml = ''.join(['<?xml version="1.0" encoding="UTF-8"?>\n'
                       '<!--Please do not manually edit this file-->\n',
                       raw_xml])

    with open('/'.join([local_manifest_dir, "roomservice.xml"]), 'w') as f:
        f.write(raw_xml)
    print("wrote the new roomservice manifest")


def parse_device_from_manifest(device):
    for project in iterate_manifests():
        name = project.get('name')
        if name.startswith("android_device_") and name.endswith(device):
            return project.get('path')
    return None


def parse_device_from_folder(device):
    search = []
    for sub_folder in os.listdir("device"):
        if os.path.isdir("device/%s/%s" % (sub_folder, device)):
            search.append("device/%s/%s" % (sub_folder, device))
    if len(search) > 1:
        print("multiple devices under the name %s. "
              "defaulting to checking the manifest" % device)
        location = parse_device_from_manifest(device)
    elif len(search) == 1:
        location = search[0]
    else:
        print("you device can't be found in device sources..")
        location = parse_device_from_manifest(device)
    return location


def parse_dependency_file(location):
    dep_file = "omni.dependencies"
    dep_location = '/'.join([location, dep_file])
    if not os.path.isfile(dep_location):
        print("WARNING: %s file not found" % dep_location)
        sys.exit()
    try:
        with open(dep_location, 'r') as f:
            dependencies = json.loads(f.read())
    except ValueError:
        raise Exception("ERROR: malformed dependency file")
    return dependencies


def create_dependency_manifest(dependencies):
    projects = []
    for dependency in dependencies:
        repository = dependency.get("repository")
        target_path = dependency.get("target_path")
        revision = dependency.get("revision", default_rev)
        remote = dependency.get("remote", default_rem)

        # not adding an organization should default to android_team
        # only apply this to github
        if remote == "github":
            if not "/" in repository:
                repository = '/'.join([android_team, repository])
        project = create_manifest_project(repository,
                                          target_path,
                                          remote=remote,
                                          revision=revision)
        if not project is None:
            manifest = append_to_manifest(project)
            write_to_manifest(manifest)
            projects.append(target_path)
    if len(projects) > 0:
        os.system("repo sync %s" % " ".join(projects))


def fetch_dependencies(device):
    location = parse_device_from_folder(device)
    if location is None or not os.path.isdir(location):
        raise Exception("ERROR: could not find your device "
                        "folder location, bailing out")
    dependencies = parse_dependency_file(location)
    create_dependency_manifest(dependencies)


def check_device_exists(device):
    location = parse_device_from_folder(device)
    if location is None:
        return False
    return os.path.isdir(location)


def fetch_device(device):
    if check_device_exists(device):
        print("WARNING: Trying to fetch a device that's already there")
        return
    git_data = search_github_for_device(device)
    device_url = get_device_url(git_data)
    device_dir = parse_device_directory(device_url)
    project = create_manifest_project(device_url,
                                      device_dir,
                                      remote=default_team_rem)
    if not project is None:
        manifest = append_to_manifest(project)
        write_to_manifest(manifest)
        print("syncing the device config")
        os.system('repo sync %s' % device_dir)


if __name__ == '__main__':
    if not os.path.isdir(local_manifest_dir):
        os.mkdir(local_manifest_dir)

    product = sys.argv[1]
    try:
        device = product[product.index("_") + 1:]
    except ValueError:
        device = product

    if len(sys.argv) > 2:
        deps_only = sys.argv[2]
    else:
        deps_only = False

    if not deps_only:
        fetch_device(device)
    fetch_dependencies(device)
