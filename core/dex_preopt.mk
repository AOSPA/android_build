####################################
# dexpreopt support - typically used on user builds to run dexopt (for Dalvik) or dex2oat (for ART) ahead of time
#
####################################

# list of boot classpath jars for dexpreopt
DEXPREOPT_BOOT_JARS := $(subst $(space),:,$(PRODUCT_BOOT_JARS))
DEXPREOPT_BOOT_JARS_MODULES := $(PRODUCT_BOOT_JARS)
PRODUCT_BOOTCLASSPATH := $(subst $(space),:,$(foreach m,$(DEXPREOPT_BOOT_JARS_MODULES),/system/framework/$(m).jar))

PRODUCT_SYSTEM_SERVER_CLASSPATH := $(subst $(space),:,$(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),/system/framework/$(m).jar))

DEXPREOPT_BUILD_DIR := $(OUT_DIR)
DEXPREOPT_PRODUCT_DIR_FULL_PATH := $(PRODUCT_OUT)/dex_bootjars
DEXPREOPT_PRODUCT_DIR := $(patsubst $(DEXPREOPT_BUILD_DIR)/%,%,$(DEXPREOPT_PRODUCT_DIR_FULL_PATH))
DEXPREOPT_BOOT_JAR_DIR := system/framework
DEXPREOPT_BOOT_JAR_DIR_FULL_PATH := $(DEXPREOPT_PRODUCT_DIR_FULL_PATH)/$(DEXPREOPT_BOOT_JAR_DIR)

# The default value for LOCAL_DEX_PREOPT
DEX_PREOPT_DEFAULT ?= true

# The default filter for which files go into the system_other image (if it is
# being used). To bundle everything one should set this to '%'
SYSTEM_OTHER_ODEX_FILTER ?= app/% priv-app/%

# Method returning whether the install path $(1) should be for system_other.
# Under SANITIZE_LITE, we do not want system_other. Just put things under /data/asan.
ifeq ($(SANITIZE_LITE),true)
install-on-system-other =
else
install-on-system-other = $(filter-out $(PRODUCT_DEXPREOPT_SPEED_APPS) $(PRODUCT_SYSTEM_SERVER_APPS),$(basename $(notdir $(filter $(foreach f,$(SYSTEM_OTHER_ODEX_FILTER),$(TARGET_OUT)/$(f)),$(1)))))
endif

# The default values for pre-opting: always preopt PIC.
# Conditional to building on linux, as dex2oat currently does not work on darwin.
ifeq ($(HOST_OS),linux)
  WITH_DEXPREOPT ?= true
  ifeq (eng,$(TARGET_BUILD_VARIANT))
    # Don't strip for quick development turnarounds.
    DEX_PREOPT_DEFAULT := nostripping
    # For an eng build only pre-opt the boot image and system server. This gives reasonable performance
    # and still allows a simple workflow: building in frameworks/base and syncing.
    WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY ?= true
  endif
  # Add mini-debug-info to the boot classpath if explicitly asked to do so.
  ifeq (true,$(WITH_DEXPREOPT_DEBUG_INFO))
    PRODUCT_DEX_PREOPT_BOOT_FLAGS += --generate-mini-debug-info
  endif

  # Non eng linux builds must have preopt enabled so that system server doesn't run as interpreter
  # only. b/74209329
  ifeq (,$(filter eng, $(TARGET_BUILD_VARIANT)))
    ifneq (true,$(WITH_DEXPREOPT))
      ifneq (true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY))
        $(call pretty-error, DEXPREOPT must be enabled for user and userdebug builds)
      endif
    endif
  endif
endif

GLOBAL_DEXPREOPT_FLAGS :=

# Special rules for building stripped boot jars that override java_library.mk rules

# $(1): boot jar module name
define _dexpreopt-boot-jar-remove-classes.dex
_dbj_jar_no_dex := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(1)_nodex.jar
_dbj_src_jar := $(call intermediates-dir-for,JAVA_LIBRARIES,$(1),,COMMON)/javalib.jar

$(call dexpreopt-copy-jar,$$(_dbj_src_jar),$$(_dbj_jar_no_dex),$(DEX_PREOPT_DEFAULT))

_dbj_jar_no_dex :=
_dbj_src_jar :=
endef

$(foreach b,$(DEXPREOPT_BOOT_JARS_MODULES),$(eval $(call _dexpreopt-boot-jar-remove-classes.dex,$(b))))

include $(BUILD_SYSTEM)/dex_preopt_libart.mk

# Define dexpreopt-one-file based on current default runtime.
# $(1): the input .jar or .apk file
# $(2): the output .odex file
define dexpreopt-one-file
$(call dex2oat-one-file,$(1),$(2))
endef

DEXPREOPT_ONE_FILE_DEPENDENCY_TOOLS := $(DEX2OAT_DEPENDENCY)
DEXPREOPT_ONE_FILE_DEPENDENCY_BUILT_BOOT_PREOPT := $(DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME)
ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)DEXPREOPT_ONE_FILE_DEPENDENCY_BUILT_BOOT_PREOPT := $($(TARGET_2ND_ARCH_VAR_PREFIX)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME)
endif  # TARGET_2ND_ARCH

ifeq ($(PRODUCT_DIST_BOOT_AND_SYSTEM_JARS),true)
boot_profile_jars_zip := $(PRODUCT_OUT)/boot_profile_jars.zip
all_boot_jars := \
  $(foreach m,$(DEXPREOPT_BOOT_JARS_MODULES),$(PRODUCT_OUT)/system/framework/$(m).jar) \
  $(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),$(PRODUCT_OUT)/system/framework/$(m).jar)

$(boot_profile_jars_zip): PRIVATE_JARS := $(all_boot_jars)
$(boot_profile_jars_zip): $(all_boot_jars) $(SOONG_ZIP)
	echo "Create boot profiles package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@ -C $(PRODUCT_OUT) $(PRIVATE_JARS)

droidcore: $(boot_profile_jars_zip)

$(call dist-for-goals, droidcore, $(boot_profile_jars_zip))
endif
