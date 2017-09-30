# Copyright (C) 2007 The Android Open Source Project
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

# Don't bother with the cleanspecs if you are running mm/mmm
ifeq ($(ONE_SHOT_MAKEFILE)$(dont_bother),)

INTERNAL_CLEAN_STEPS :=

# Builds up a list of clean steps.  Creates a unique
# id for each step by taking makefile path, INTERNAL_CLEAN_BUILD_VERSION
# and appending an increasing number of '@' characters.
#
# $(1): shell command to run
# $(2): indicate to not use makefile path as part of step id if not empty.
#       $(2) should only be used in build/core/cleanspec.mk: just for compatibility.
define _add-clean-step
  $(if $(strip $(INTERNAL_CLEAN_BUILD_VERSION)),, \
      $(error INTERNAL_CLEAN_BUILD_VERSION not set))
  $(eval _acs_makefile_prefix := $(lastword $(MAKEFILE_LIST)))
  $(eval _acs_makefile_prefix := $(subst /,_,$(_acs_makefile_prefix)))
  $(eval _acs_makefile_prefix := $(subst .,-,$(_acs_makefile_prefix)))
  $(eval _acs_makefile_prefix := $(_acs_makefile_prefix)_acs)
  $(if $($(_acs_makefile_prefix)),,\
      $(eval $(_acs_makefile_prefix) := $(INTERNAL_CLEAN_BUILD_VERSION)))
  $(eval $(_acs_makefile_prefix) := $($(_acs_makefile_prefix))@)
  $(if $(strip $(2)),$(eval _acs_id := $($(_acs_makefile_prefix))),\
      $(eval _acs_id := $(_acs_makefile_prefix)$($(_acs_makefile_prefix))))
  $(eval INTERNAL_CLEAN_STEPS += $(_acs_id))
  $(eval INTERNAL_CLEAN_STEP.$(_acs_id) := $(1))
  $(eval _acs_id :=)
  $(eval _acs_makefile_prefix :=)
endef
define add-clean-step
$(eval # for build/core/cleanspec.mk, dont use makefile path as part of step id) \
$(if $(filter %/cleanspec.mk,$(lastword $(MAKEFILE_LIST))),\
    $(eval $(call _add-clean-step,$(1),true)),\
    $(eval $(call _add-clean-step,$(1))))
endef

# Defines INTERNAL_CLEAN_BUILD_VERSION and the individual clean steps.
# cleanspec.mk is outside of the core directory so that more people
# can have permission to touch it.
include $(BUILD_SYSTEM)/cleanspec.mk
INTERNAL_CLEAN_BUILD_VERSION := $(strip $(INTERNAL_CLEAN_BUILD_VERSION))
INTERNAL_CLEAN_STEPS := $(strip $(INTERNAL_CLEAN_STEPS))

# If the clean_steps.mk file is missing (usually after a clean build)
# then we won't do anything.
CURRENT_CLEAN_BUILD_VERSION := $(INTERNAL_CLEAN_BUILD_VERSION)
CURRENT_CLEAN_STEPS := $(INTERNAL_CLEAN_STEPS)

# Read the current state from the file, if present.
# Will set CURRENT_CLEAN_BUILD_VERSION and CURRENT_CLEAN_STEPS.
#
clean_steps_file := $(PRODUCT_OUT)/clean_steps.mk
-include $(clean_steps_file)

ifneq ($(CURRENT_CLEAN_BUILD_VERSION),$(INTERNAL_CLEAN_BUILD_VERSION))
  # The major clean version is out-of-date.  Do a full clean, and
  # don't even bother with the clean steps.
  $(info *** A clean build is required because of a recent change.)
  $(shell rm -rf $(OUT_DIR))
  $(info *** Done with the cleaning, now starting the real build.)
else
  # The major clean version is correct.  Find the list of clean steps
  # that we need to execute to get up-to-date.
  steps := \
      $(filter-out $(CURRENT_CLEAN_STEPS),$(INTERNAL_CLEAN_STEPS))
  $(foreach step,$(steps), \
    $(info Clean step: $(INTERNAL_CLEAN_STEP.$(step))) \
    $(shell $(INTERNAL_CLEAN_STEP.$(step))) \
   )

  # Rewrite the clean step for the second arch.
  ifdef TARGET_2ND_ARCH
  # $(1): the clean step cmd
  # $(2): the prefix to search for
  # $(3): the prefix to replace with
  define -cs-rewrite-cleanstep
  $(if $(filter $(2)/%,$(1)),\
    $(eval _crs_new_cmd := $(patsubst $(2)/%,$(3)/%,$(1)))\
    $(info Clean step: $(_crs_new_cmd))\
    $(shell $(_crs_new_cmd)))
  endef
  $(foreach step,$(steps), \
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_INTERMEDIATES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_SHARED_LIBRARIES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_VENDOR_SHARED_LIBRARIES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES),$(TARGET_OUT_INTERMEDIATES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES),$(TARGET_OUT_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES),$(TARGET_OUT_VENDOR_SHARED_LIBRARIES))\
    )
  endif
  _crs_new_cmd :=
  steps :=
endif

# Write the new state to the file.
#
rewrite_clean_steps_file :=
ifneq ($(CURRENT_CLEAN_BUILD_VERSION)-$(CURRENT_CLEAN_STEPS),$(INTERNAL_CLEAN_BUILD_VERSION)-$(INTERNAL_CLEAN_STEPS))
rewrite_clean_steps_file := true
endif
ifeq ($(wildcard $(clean_steps_file)),)
# This is the first build.
rewrite_clean_steps_file := true
endif
ifeq ($(rewrite_clean_steps_file),true)
$(shell \
  mkdir -p $(dir $(clean_steps_file)) && \
  echo "CURRENT_CLEAN_BUILD_VERSION := $(INTERNAL_CLEAN_BUILD_VERSION)" > \
      $(clean_steps_file) ;\
  echo "CURRENT_CLEAN_STEPS := $(wordlist 1,500,$(INTERNAL_CLEAN_STEPS))" >> $(clean_steps_file) \
 )
define -cs-write-clean-steps-if-arg1-not-empty
$(if $(1),$(shell echo "CURRENT_CLEAN_STEPS += $(1)" >> $(clean_steps_file)))
endef
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 501,1000,$(INTERNAL_CLEAN_STEPS)))
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 1001,1500,$(INTERNAL_CLEAN_STEPS)))
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 1501,2000,$(INTERNAL_CLEAN_STEPS)))
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 2001,2500,$(INTERNAL_CLEAN_STEPS)))
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 2501,3000,$(INTERNAL_CLEAN_STEPS)))
$(call -cs-write-clean-steps-if-arg1-not-empty,$(wordlist 3001,99999,$(INTERNAL_CLEAN_STEPS)))
endif

CURRENT_CLEAN_BUILD_VERSION :=
CURRENT_CLEAN_STEPS :=
clean_steps_file :=
rewrite_clean_steps_file :=
INTERNAL_CLEAN_STEPS :=
INTERNAL_CLEAN_BUILD_VERSION :=

endif  # if not ONE_SHOT_MAKEFILE dont_bother

# Since products and build variants (unfortunately) share the same
# PRODUCT_OUT staging directory, things can get out of sync if different
# build configurations are built in the same tree.  The following logic
# will notice when the configuration has changed and remove the files
# necessary to keep things consistent.

previous_build_config_file := $(PRODUCT_OUT)/previous_build_config.mk
current_build_config_file := $(PRODUCT_OUT)/current_build_config.mk

current_build_config := \
    $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)
force_installclean := false

# Read the current state from the file, if present.
# Will set PREVIOUS_BUILD_CONFIG.
#
PREVIOUS_BUILD_CONFIG :=
-include $(previous_build_config_file)
PREVIOUS_BUILD_CONFIG := $(strip $(PREVIOUS_BUILD_CONFIG))

ifdef PREVIOUS_BUILD_CONFIG
  ifneq ($(current_build_config),$(PREVIOUS_BUILD_CONFIG))
    $(info *** Build configuration changed: "$(PREVIOUS_BUILD_CONFIG)" -> "$(current_build_config)")
    ifneq ($(DISABLE_AUTO_INSTALLCLEAN),true)
      force_installclean := true
    else
      $(info DISABLE_AUTO_INSTALLCLEAN is set; skipping auto-clean. Your tree may be in an inconsistent state.)
    endif
  endif
endif  # else, this is the first build, so no need to clean.

# Write the new state to the file.
#
$(shell \
  mkdir -p $(dir $(current_build_config_file)) && \
  echo "PREVIOUS_BUILD_CONFIG := $(current_build_config)" > \
      $(current_build_config_file) \
 )
$(shell cmp $(current_build_config_file) $(previous_build_config_file) > /dev/null 2>&1 || \
  mv -f $(current_build_config_file) $(previous_build_config_file))

PREVIOUS_BUILD_CONFIG :=
previous_build_config_file :=
current_build_config_file :=
current_build_config :=

#
# installclean logic
#

# The files/dirs to delete during an installclean.
#
# Deletes all of the installed files -- the intent is to remove files
# that may no longer be installed, either because the user previously
# installed them, or they were previously installed by default but no
# longer are.
#
# This is faster than a full clean, since we're not deleting the
# intermediates. Instead of recompiling, we can just copy the results.
#
# Host bin, frameworks, and lib* are intentionally omitted, since
# otherwise we'd have to rebuild any generated files created with those
# tools.
installclean_files := \
	$(HOST_OUT)/obj/NOTICE_FILES \
	$(HOST_OUT)/obj/PACKAGING \
	$(HOST_OUT)/coverage \
	$(HOST_OUT)/cts \
	$(HOST_OUT)/nativetest* \
	$(HOST_OUT)/sdk \
	$(HOST_OUT)/sdk_addon \
	$(HOST_OUT)/testcases \
	$(HOST_OUT)/vts \
	$(HOST_CROSS_OUT)/bin \
	$(HOST_CROSS_OUT)/coverage \
	$(HOST_CROSS_OUT)/lib* \
	$(HOST_CROSS_OUT)/nativetest* \
	$(PRODUCT_OUT)/*.img \
	$(PRODUCT_OUT)/*.ini \
	$(PRODUCT_OUT)/*.txt \
	$(PRODUCT_OUT)/*.xlb \
	$(PRODUCT_OUT)/*.zip \
	$(PRODUCT_OUT)/kernel \
	$(PRODUCT_OUT)/*.zip.md5sum \
	$(PRODUCT_OUT)/data \
	$(PRODUCT_OUT)/skin \
	$(PRODUCT_OUT)/obj/NOTICE_FILES \
	$(PRODUCT_OUT)/obj/PACKAGING \
	$(PRODUCT_OUT)/recovery \
	$(PRODUCT_OUT)/root \
	$(PRODUCT_OUT)/system \
	$(PRODUCT_OUT)/system_other \
	$(PRODUCT_OUT)/vendor \
	$(PRODUCT_OUT)/oem \
	$(PRODUCT_OUT)/obj/FAKE \
	$(PRODUCT_OUT)/breakpad \
	$(PRODUCT_OUT)/cache \
	$(PRODUCT_OUT)/coverage \
	$(PRODUCT_OUT)/installer \
	$(PRODUCT_OUT)/odm \
	$(PRODUCT_OUT)/sysloader \
	$(PRODUCT_OUT)/testcases \

# The files/dirs to delete during a dataclean, which removes any files
# in the staging and emulator data partitions.
dataclean_files := \
	$(PRODUCT_OUT)/data/* \
	$(PRODUCT_OUT)/data-qemu/* \
	$(PRODUCT_OUT)/userdata-qemu.img

# make sure *_OUT is set so that we won't result in deleting random parts
# of the filesystem.
ifneq (2,$(words $(HOST_OUT) $(PRODUCT_OUT)))
  $(error both HOST_OUT and PRODUCT_OUT should be set at this point.)
endif

# Define the rules for commandline invocation.
.PHONY: dataclean
dataclean: FILES := $(dataclean_files)
dataclean:
	$(hide) rm -rf $(FILES)
	@echo "Deleted emulator userdata images."

.PHONY: installclean
installclean: FILES := $(installclean_files)
installclean: dataclean
	$(hide) rm -rf $(FILES)
	@echo "Deleted images and staging directories."

ifeq ($(force_installclean),true)
  $(info *** Forcing "make installclean"...)
  $(info *** rm -rf $(dataclean_files) $(installclean_files))
  $(shell rm -rf $(dataclean_files) $(installclean_files))
  $(info *** Done with the cleaning, now starting the real build.)
endif
force_installclean :=

###########################################################

.PHONY: clean-jack-files
clean-jack-files: clean-dex-files
	$(hide) find $(OUT_DIR) -name "*.jack" | xargs rm -f
	$(hide) find $(OUT_DIR) -type d -name "jack" | xargs rm -rf
	@echo "All jack files have been removed."

.PHONY: clean-dex-files
clean-dex-files:
	$(hide) find $(OUT_DIR) -name "*.dex" ! -path "*/jack-incremental/*" | xargs rm -f
	$(hide) for i in `find $(OUT_DIR) -name "*.jar" -o -name "*.apk"` ; do ((unzip -l $$i 2> /dev/null | \
				grep -q "\.dex$$" && rm -f $$i) || continue ) ; done
	@echo "All dex files and archives containing dex files have been removed."

.PHONY: clean-jack-incremental
clean-jack-incremental:
	$(hide) find $(OUT_DIR) -name "jack-incremental" -type d | xargs rm -rf
	@echo "All jack incremental dirs have been removed."
