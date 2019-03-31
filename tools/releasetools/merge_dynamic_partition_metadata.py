#!/usr/bin/env python
# Copyright (c) 2019, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE US

"""
This script  merges the contents of the dynamic_partition_metadata.txt
files from the qssi directory and the target directory, placing the merged
result in the merged dynamic partition metadata file.

Usage: merge_dynamic_partition_metadata.py [args]

    --qssi-dpm-file : File containing QSSI dynamic partition
    information generated during QSSI lunch make.

    --target-dpm-file : File containing QSSI dynamic partition
    information generated during target lunch make.

    --merged-dpm-file : This file will contain collated metadata
    information of dynamic partitions from qssi and target.
"""

from __future__ import print_function

import common
import sys
import os
import logging

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS
OPTIONS.verbose = True
OPTIONS.qssi_dynamic_partition_metadata_file = None
OPTIONS.target_dynamic_partition_metadata_file = None
OPTIONS.merged_dynamic_partition_metadata_file = None

def merge_dynamic_partition_metadata(
    qssi_dynamic_partition_metadata_file,
    target_dynamic_partition_metadata_file,
    merged_dynamic_partition_metadata_file):
  """

  This function merges the contents of the dynamic_partition_metadata.txt
  files from the qssi directory and the target directory, placing the merged
  result in the merged dynamic partition metadata file.

  Args:
    qssi_dynamic_partition_metadata_file: File containing QSSI dynamic partition
    information generated during QSSI lunch make.

    target_dynamic_partition_metadata_file: File containing QSSI dynamic partition
    information generated during target lunch make.

    merged_dynamic_partition_metadata_file : This file will contain collated metadata
    information of dynamic partitions from qssi and target.
  """
  def read_helper(dynamic_metadata_file):
    with open(dynamic_metadata_file) as f:
      return list(f.read().splitlines())

  qssi_metadata_dict = common.LoadDictionaryFromLines(
      read_helper(qssi_dynamic_partition_metadata_file))

  merged_metadata_dict = common.LoadDictionaryFromLines(
      read_helper(target_dynamic_partition_metadata_file))

  if merged_metadata_dict['use_dynamic_partitions'] == 'true':
    merged_metadata_dict['dynamic_partition_list'] = '%s %s' % (
      qssi_metadata_dict.get('dynamic_partition_list', ''),
      merged_metadata_dict.get('dynamic_partition_list', ''))
  else:
    logger.warning("Dynamic patiitions is not enabled, Exiting!!")
    sys.exit(1)

  for partition_group in merged_metadata_dict['super_partition_groups'].split(' '):
    key = 'super_%s_partition_list' % partition_group
    merged_metadata_dict[key] = '%s %s' % (
      qssi_metadata_dict.get(key, ''),
      merged_metadata_dict.get(key, ''))

  sorted_keys = sorted(merged_metadata_dict.keys())
  if os.path.exists(merged_dynamic_partition_metadata_file):
    os.remove(merged_dynamic_partition_metadata_file)
  with open(merged_dynamic_partition_metadata_file, 'w') as merged_dpm_file:
    for key in sorted_keys:
      merged_dpm_file.write('{}={}\n'.format(key, merged_metadata_dict[key]))
  logger.info("Generated merged dynamic partition metdata file : %s",merged_dynamic_partition_metadata_file)

def main():

  common.InitLogging()

  def option_handler(o, a):
    if o == '--qssi-dpm-file':
      OPTIONS.qssi_dynamic_partition_metadata_file = a
    elif o == '--target-dpm-file':
      OPTIONS.target_dynamic_partition_metadata_file = a
    elif o == '--merged-dpm-file':
      OPTIONS.merged_dynamic_partition_metadata_file = a
    else:
      return False
    return True

  args = common.ParseOptions(
      sys.argv[1:], __doc__,
          extra_long_opts=[
          'qssi-dpm-file=',
          'target-dpm-file=',
          'merged-dpm-file=',
    ],
    extra_option_handler=option_handler)

  if (len(args) != 0 or
      OPTIONS.qssi_dynamic_partition_metadata_file is None or
      OPTIONS.target_dynamic_partition_metadata_file is None or
      OPTIONS.merged_dynamic_partition_metadata_file is None):
    common.Usage(__doc__)
    sys.exit(1)

  merge_dynamic_partition_metadata(
      OPTIONS.qssi_dynamic_partition_metadata_file,
      OPTIONS.target_dynamic_partition_metadata_file,
      OPTIONS.merged_dynamic_partition_metadata_file)

if __name__ == '__main__':
  main()

