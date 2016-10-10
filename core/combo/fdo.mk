#
# Copyright (C) 2006 The Android Open Source Project
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

# Setup FDO related flags.

$(combo_2nd_arch_prefix)TARGET_FDO_CFLAGS:=

# Set BUILD_FDO_INSTRUMENT=true to turn on FDO instrumentation.
# The profile will be generated on /sdcard/fdo_profile on the device.
$(combo_2nd_arch_prefix)TARGET_FDO_INSTRUMENT_CFLAGS := -fprofile-generate=/sdcard/fdo_profile --coverage -DANDROID_FDO
$(combo_2nd_arch_prefix)TARGET_FDO_INSTRUMENT_LDFLAGS := --coverage

# Set TARGET_FDO_PROFILE_PATH to set a custom profile directory for your build.
ifeq ($(strip $($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH)),)
  $(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH := vendor/google_data/fdo_profile
endif

$(combo_2nd_arch_prefix)TARGET_FDO_OPTIMIZE_CFLAGS := \
    -fprofile-use=$($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH) \
    -DANDROID_FDO -fprofile-correction -Wcoverage-mismatch -Wno-error
