#
# Copyright (C) 2008 The Android Open Source Project
# Copyright (C) 2017 Paranoid Android
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

# The default value for LOCAL_DEX_PREOPT.
DEX_PREOPT_DEFAULT ?= true

# The default filter for which files go into the system_other image (if it is
# being used). To bundle everything one should set this to '%'.
SYSTEM_OTHER_ODEX_FILTER ?= app/% priv-app/%

# The default values for pre-opting: never preopt PIC.
# Conditional to building on linux, as dex2oat currently does not work on darwin.
ifeq ($(HOST_OS),linux)
  # Use the shell environment variable "USE_DEXPREOPT" to define the pre-optimization values.
  ifneq ($(filter-out true,$(USE_DEXPREOPT)),)
    # If the variable "USE_DEXPREOPT" is set to "false", pre-opting will be uncondionally disabled.
    WITH_DEXPREOPT ?= false
  else
    # If the variable "USE_DEXPREOPT" is not set or set to "true", pre-opting will use the default values.
    WITH_DEXPREOPT ?= true
    # Enable position-independent code by default.
    WITH_DEXPREOPT_PIC ?= true
    # For userdebug or eng builds only pre-opt the boot image. This gives reasonable performance and still
    # allows a simple workflow: building in frameworks/base and syncing.
    ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
      WITH_DEXPREOPT_BOOT_IMG_ONLY ?= true
    endif
    # Add mini-debug-info to the boot classpath if explicitly asked to do so.
    ifeq (true,$(WITH_DEXPREOPT_DEBUG_INFO))
      PRODUCT_DEX_PREOPT_BOOT_FLAGS += --generate-mini-debug-info
    endif
  endif
endif

GLOBAL_DEXPREOPT_FLAGS :=
ifeq ($(WITH_DEXPREOPT_PIC),true)
# Compile boot.oat as position-independent code if WITH_DEXPREOPT_PIC=true.
GLOBAL_DEXPREOPT_FLAGS += --compile-pic
endif
