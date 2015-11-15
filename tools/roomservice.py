#!/usr/bin/env python

# roomservice: Android device repository management utility.
# Copyright (C) 2013 Cybojenix <anthonydking@gmail.com>
# Copyright (C) 2013 The OmniROM Project
# Copyright (C) 2015 ParanoidAndroid Project
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

import json
import os
import sys
from xml.etree import ElementTree as ET

upstream_manifest_path = '.repo/manifest.xml'
local_manifests_dir = '.repo/local_manifests'
roomservice_manifest_path = local_manifests_dir + '/roomservice.xml'
dependencies_json_path = 'vendor/pa/products/%s/pa.dependencies'

# Indenting code from https://stackoverflow.com/a/4590052
def indent(elem, level=0):
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent(elem, level + 1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

if __name__ == '__main__':
    if not os.path.isdir(local_manifests_dir):
        os.mkdir(local_manifests_dir)

    if len(sys.argv) <= 1:
        raise ValueError('The first argument must be the product.')
    product = sys.argv[1]

    try:
        device = product[product.index('_') + 1:]
    except ValueError:
        device = product

    dependencies_json_path %= device
    if not os.path.isfile(dependencies_json_path):
        raise ValueError('No dependencies file could be found for the device (%s).' % device)
    dependencies = json.loads(open(dependencies_json_path, 'r').read())

    try:
        upstream_manifest = ET.parse(upstream_manifest_path).getroot()
    except (IOError, ET.ParseError):
        upstream_manifest = ET.Element('manifest')

    try:
        roomservice_manifest = ET.parse(roomservice_manifest_path).getroot()
    except (IOError, ET.ParseError):
        roomservice_manifest = ET.Element('manifest')

    syncable_projects = []

    # Clean up all the <remove-project> elements.
    for removable_project in roomservice_manifest.findall('remove-project'):
        name = removable_project.get('name')

        path = None
        for project in upstream_manifest.findall('project'):
            if project.get('name') == name:
                path = project.get('path')
                break

        if path is None:
            # The upstream manifest doesn't know this project, so drop it.
            roomservice_manifest.remove(removable_project)
            continue

        found_in_dependencies = False
        for dependency in dependencies:
            if dependency.get('target_path') == path:
                found_in_dependencies = True
                break

        if not found_in_dependencies:
            # We don't need special dependencies for this project, so drop it and sync it up.
            roomservice_manifest.remove(removable_project)
            syncable_projects.append(path)
            for project in roomservice_manifest.findall('project'):
                if project.get('path') == path:
                    roomservice_manifest.remove(project)
                    break

    # Make sure our <project> elements are set.
    for dependency in dependencies:
        path = dependency.get('target_path')
        name = dependency.get('repository')
        remote = dependency.get('remote')
        revision = dependency.get('revision')

        modified_project = False
        found_in_roomservice = False

        # In case the project was already added, update it.
        for project in roomservice_manifest.findall('project'):
            if project.get('name') == name:
                found_in_roomservice = True
                if project.get('path') != path:
                    modified_project = True
                    project.set('path', path)
                if project.get('remote') != remote:
                    modified_project = True
                    project.set('remote', remote)
                if project.get('revision') != revision:
                    modified_project = True
                    project.set('revision', revision)
                break

        # In case the project was not already added, create it.
        if not found_in_roomservice:
            found_in_roomservice = True
            modified_project = True
            roomservice_manifest.append(ET.Element('project', attrib = {
                'path': path,
                'name': name,
                'remote': remote,
                'revision': revision
            }))

        # In case the project also exists in the main manifest, instruct Repo to ignore that one.
        for project in upstream_manifest.findall('project'):
            if project.get('path') == path:
                upstream_name = project.get('name')
                found_remove_element = False
                for removable_project in roomservice_manifest.findall('remove-project'):
                    if removable_project.get('name') == upstream_name:
                        found_remove_element = True
                        break
                if not found_remove_element:
                    modified_project = True
                    roomservice_manifest.insert(0, ET.Element('remove-project', attrib = {
                        'name': upstream_name
                    }))

        # In case anything has changed, set the project as syncable.
        if modified_project:
            syncable_projects.append(path)

    # Output our manifest.
    indent(roomservice_manifest)
    open(roomservice_manifest_path, 'w').write('\n'.join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!-- You should probably let Roomservice deal with this unless you know what you are doing. -->',
        ET.tostring(roomservice_manifest).decode()
    ]))

    # Sync the project that have changed and should be synced.
    if len(syncable_projects) > 0:
        print('Syncing the dependencies.')
        if os.system('repo sync --force-broken --quiet --no-clone-bundle %s' % ' '.join(syncable_projects)) != 0:
            raise ValueError('Got an unexpected exit status from the sync process.')
