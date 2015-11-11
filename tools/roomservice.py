#!/usr/bin/env python2

# Copyright (C) 2015 The Paranoid Android Project
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
import re
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

# Default remote to use in repo
default_rem = "aospa"
# Default revision to use (branch/tag name)
default_rev = "marshmallow"

# Default local manifest location
local_manifest_dir = ".repo/local_manifests"
# Default dependencies location
dependencies_dir = "vendor/pa/products"

# Contribution by RaYmAn
def iterate_manifests(check_all):
    files = []
    if check_all:
        for file in os.listdir(local_manifest_dir):
            files.append(os.path.join(local_manifest_dir, file))
    files.append('.repo/manifest.xml')
    for file in files:
        try:
            man = ES.parse(file)
            man = man.getroot()
        except IOError, ES.ParseError:
            print("WARNING: Error while parsing %s" % file)
        else:
            for project in man.findall("project"):
                yield project


def check_project_exists(url):
    for project in iterate_manifests(True):
        if project.get("name") == url:
            return True
    return False


def check_dup_path(directory):
    for project in iterate_manifests(False):
        if project.get("path") == directory:
            print ("Duplicate path %s found! Removing" % directory)
            return project.get("name")
    return None


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

    dup_path = check_dup_path(directory)
    if not dup_path is None:
            write_to_manifest(
                append_to_manifest(
                    create_manifest_remove(dup_path)))

    project = ES.Element("project",
                         attrib={
                             "path": directory,
                             "name": url,
                             "remote": remote,
                             "revision": revision
                         })
    return project


def create_manifest_remove(url):
    remove = ES.Element("remove-project", attrib={"name": url})
    return remove


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
    print("Wrote the new roomservice manifest")


def parse_device_from_manifest(device):
    for project in iterate_manifests(True):
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
        print("your device can't be found in device sources...")
        location = parse_device_from_manifest(device)
    return location


def parse_dependency_file(device):
    dep_location = dependencies_dir + '/{}/pa.dependencies'.format(device)
    if not os.path.isfile(dep_location):
        print("WARNING: %s file not found" % dep_location)
        sys.exit()
    try:
        with open(dep_location, 'r') as f:
            dependencies = json.loads(f.read())
    except ValueError:
        raise Exception("ERROR: Malformed dependency file")
    return dependencies


def create_dependency_manifest(dependencies):
    projects = []
    for dependency in dependencies:
        repository = dependency.get("repository")
        target_path = dependency.get("target_path")
        revision = dependency.get("revision", default_rev)
        remote = dependency.get("remote", default_rem)

        project = create_manifest_project(repository,
                                          target_path,
                                          remote=remote,
                                          revision=revision)
        if not project is None:
            manifest = append_to_manifest(project)
            write_to_manifest(manifest)
            projects.append(target_path)
    if len(projects) > 0:
        os.system("repo sync --force-sync --no-clone-bundle %s" % " ".join(projects))


def fetch_dependencies(device):
    dependencies = parse_dependency_file(device)
    create_dependency_manifest(dependencies)


def check_device_exists(device):
    location = parse_device_from_folder(device)
    if location is None:
        return False
    return os.path.isdir(location)


if __name__ == '__main__':
    if not os.path.isdir(local_manifest_dir):
        os.mkdir(local_manifest_dir)

    product = sys.argv[1]
    try:
        device = product[product.index("_") + 1:]
    except ValueError:
        device = product

    fetch_dependencies(device)
