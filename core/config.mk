# This is included by the top-level Makefile.
# It sets up standard variables based on the
# current configuration and platform, which
# are not specific to what is being built.

ifndef KATI
$(warning Directly using config.mk from make is no longer supported.)
$(warning )
$(warning If you are just attempting to build, you probably need to re-source envsetup.sh:)
$(warning )
$(warning $$ source build/envsetup.sh)
$(warning )
$(warning If you are attempting to emulate get_build_var, use one of the following:)
$(warning $$ build/soong/soong_ui.bash --dumpvar-mode)
$(warning $$ build/soong/soong_ui.bash --dumpvars-mode)
$(warning )
$(error done)
endif

BUILD_SYSTEM :=$= build/make/core
BUILD_SYSTEM_COMMON :=$= build/make/common

include $(BUILD_SYSTEM_COMMON)/core.mk

# Mark variables that should be coming as environment variables from soong_ui
# as readonly
.KATI_READONLY := OUT_DIR TMPDIR BUILD_DATETIME_FILE
ifdef CALLED_FROM_SETUP
  .KATI_READONLY := CALLED_FROM_SETUP
endif
ifdef KATI_PACKAGE_MK_DIR
  .KATI_READONLY := KATI_PACKAGE_MK_DIR
endif

# Mark variables deprecated/obsolete
CHANGES_URL := https://android.googlesource.com/platform/build/+/master/Changes.md
.KATI_READONLY := CHANGES_URL
$(KATI_obsolete_var PATH,Do not use PATH directly. See $(CHANGES_URL)#PATH)
$(KATI_obsolete_var PYTHONPATH,Do not use PYTHONPATH directly. See $(CHANGES_URL)#PYTHONPATH)
$(KATI_obsolete_var OUT,Use OUT_DIR instead. See $(CHANGES_URL)#OUT)
$(KATI_obsolete_var ANDROID_HOST_OUT,Use HOST_OUT instead. See $(CHANGES_URL)#ANDROID_HOST_OUT)
$(KATI_obsolete_var ANDROID_PRODUCT_OUT,Use PRODUCT_OUT instead. See $(CHANGES_URL)#ANDROID_PRODUCT_OUT)
$(KATI_obsolete_var ANDROID_HOST_OUT_TESTCASES,Use HOST_OUT_TESTCASES instead. See $(CHANGES_URL)#ANDROID_HOST_OUT_TESTCASES)
$(KATI_obsolete_var ANDROID_TARGET_OUT_TESTCASES,Use TARGET_OUT_TESTCASES instead. See $(CHANGES_URL)#ANDROID_TARGET_OUT_TESTCASES)
$(KATI_obsolete_var ANDROID_BUILD_TOP,Use '.' instead. See $(CHANGES_URL)#ANDROID_BUILD_TOP)
$(KATI_obsolete_var \
  ANDROID_TOOLCHAIN \
  ANDROID_TOOLCHAIN_2ND_ARCH \
  ANDROID_DEV_SCRIPTS \
  ANDROID_EMULATOR_PREBUILTS \
  ANDROID_PRE_BUILD_PATHS \
  ,See $(CHANGES_URL)#other_envsetup_variables)
$(KATI_obsolete_var PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE,Set FCM Version in device manifest instead. See $(CHANGES_URL)#PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE)
$(KATI_obsolete_var USE_CLANG_PLATFORM_BUILD,Clang is the only supported Android compiler. See $(CHANGES_URL)#USE_CLANG_PLATFORM_BUILD)
$(KATI_obsolete_var BUILD_DROIDDOC,Droiddoc is only supported in Soong. See details on build/soong/java/droiddoc.go)
$(KATI_obsolete_var BUILD_APIDIFF,Apidiff is only supported in Soong. See details on build/soong/java/droiddoc.go)
$(KATI_obsolete_var \
  DEFAULT_GCC_CPP_STD_VERSION \
  HOST_GLOBAL_CFLAGS 2ND_HOST_GLOBAL_CFLAGS \
  HOST_GLOBAL_CONLYFLAGS 2ND_HOST_GLOBAL_CONLYFLAGS \
  HOST_GLOBAL_CPPFLAGS 2ND_HOST_GLOBAL_CPPFLAGS \
  HOST_GLOBAL_LDFLAGS 2ND_HOST_GLOBAL_LDFLAGS \
  HOST_GLOBAL_LLDFLAGS 2ND_HOST_GLOBAL_LLDFLAGS \
  HOST_CLANG_SUPPORTED 2ND_HOST_CLANG_SUPPORTED \
  HOST_CC 2ND_HOST_CC \
  HOST_CXX 2ND_HOST_CXX \
  HOST_CROSS_GLOBAL_CFLAGS 2ND_HOST_CROSS_GLOBAL_CFLAGS \
  HOST_CROSS_GLOBAL_CONLYFLAGS 2ND_HOST_CROSS_GLOBAL_CONLYFLAGS \
  HOST_CROSS_GLOBAL_CPPFLAGS 2ND_HOST_CROSS_GLOBAL_CPPFLAGS \
  HOST_CROSS_GLOBAL_LDFLAGS 2ND_HOST_CROSS_GLOBAL_LDFLAGS \
  HOST_CROSS_GLOBAL_LLDFLAGS 2ND_HOST_CROSS_GLOBAL_LLDFLAGS \
  HOST_CROSS_CLANG_SUPPORTED 2ND_HOST_CROSS_CLANG_SUPPORTED \
  HOST_CROSS_CC 2ND_HOST_CROSS_CC \
  HOST_CROSS_CXX 2ND_HOST_CROSS_CXX \
  TARGET_GLOBAL_CFLAGS 2ND_TARGET_GLOBAL_CFLAGS \
  TARGET_GLOBAL_CONLYFLAGS 2ND_TARGET_GLOBAL_CONLYFLAGS \
  TARGET_GLOBAL_CPPFLAGS 2ND_TARGET_GLOBAL_CPPFLAGS \
  TARGET_GLOBAL_LDFLAGS 2ND_TARGET_GLOBAL_LDFLAGS \
  TARGET_GLOBAL_LLDFLAGS 2ND_TARGET_GLOBAL_LLDFLAGS \
  TARGET_CLANG_SUPPORTED 2ND_TARGET_CLANG_SUPPORTED \
  TARGET_CC 2ND_TARGET_CC \
  TARGET_CXX 2ND_TARGET_CXX \
  TARGET_TOOLCHAIN_ROOT 2ND_TARGET_TOOLCHAIN_ROOT \
  HOST_TOOLCHAIN_ROOT 2ND_HOST_TOOLCHAIN_ROOT \
  HOST_CROSS_TOOLCHAIN_ROOT 2ND_HOST_CROSS_TOOLCHAIN_ROOT \
  HOST_TOOLS_PREFIX 2ND_HOST_TOOLS_PREFIX \
  HOST_CROSS_TOOLS_PREFIX 2ND_HOST_CROSS_TOOLS_PREFIX \
  HOST_GCC_VERSION 2ND_HOST_GCC_VERSION \
  HOST_CROSS_GCC_VERSION 2ND_HOST_CROSS_GCC_VERSION \
  TARGET_NDK_GCC_VERSION 2ND_TARGET_NDK_GCC_VERSION \
  GLOBAL_CFLAGS_NO_OVERRIDE GLOBAL_CPPFLAGS_NO_OVERRIDE \
  ,GCC support has been removed. Use Clang instead)
$(KATI_obsolete_var DIST_DIR dist_goal,Use dist-for-goals instead. See $(CHANGES_URL)#dist)
$(KATI_obsolete_var TARGET_ANDROID_FILESYSTEM_CONFIG_H,Use TARGET_FS_CONFIG_GEN instead)
$(KATI_deprecated_var USER,Use BUILD_USERNAME instead. See $(CHANGES_URL)#USER)

# This is marked as obsolete in envsetup.mk after reading the BoardConfig.mk
$(KATI_deprecate_export It is a global setting. See $(CHANGES_URL)#export_keyword)

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

ORIGINAL_MAKECMDGOALS := $(MAKECMDGOALS)

UNAME := $(shell uname -sm)

SRC_TARGET_DIR := $(TOPDIR)build/target

# Some specific paths to tools
SRC_DROIDDOC_DIR := $(TOPDIR)build/make/tools/droiddoc

# Mark some inputs as readonly
ifdef TARGET_DEVICE_DIR
  .KATI_READONLY := TARGET_DEVICE_DIR
endif

ONE_SHOT_MAKEFILE :=
.KATI_READONLY := ONE_SHOT_MAKEFILE

# Set up efficient math functions which are used in make.
# Here since this file is included by envsetup as well as during build.
include $(BUILD_SYSTEM_COMMON)/math.mk

include $(BUILD_SYSTEM_COMMON)/strings.mk

include $(BUILD_SYSTEM_COMMON)/json.mk

# Various mappings to avoid hard-coding paths all over the place
include $(BUILD_SYSTEM)/pathmap.mk

# Allow projects to define their own globally-available variables
include $(BUILD_SYSTEM)/project_definitions.mk

# ###############################################################
# Build system internal files
# ###############################################################

BUILD_COMBOS:= $(BUILD_SYSTEM)/combo

CLEAR_VARS:= $(BUILD_SYSTEM)/clear_vars.mk
BUILD_HOST_STATIC_LIBRARY:= $(BUILD_SYSTEM)/host_static_library.mk
BUILD_HOST_SHARED_LIBRARY:= $(BUILD_SYSTEM)/host_shared_library.mk
BUILD_STATIC_LIBRARY:= $(BUILD_SYSTEM)/static_library.mk
BUILD_HEADER_LIBRARY:= $(BUILD_SYSTEM)/header_library.mk
BUILD_AUX_STATIC_LIBRARY:= $(BUILD_SYSTEM)/aux_static_library.mk
BUILD_AUX_EXECUTABLE:= $(BUILD_SYSTEM)/aux_executable.mk
BUILD_SHARED_LIBRARY:= $(BUILD_SYSTEM)/shared_library.mk
BUILD_EXECUTABLE:= $(BUILD_SYSTEM)/executable.mk
BUILD_HOST_EXECUTABLE:= $(BUILD_SYSTEM)/host_executable.mk
BUILD_PACKAGE:= $(BUILD_SYSTEM)/package.mk
BUILD_PHONY_PACKAGE:= $(BUILD_SYSTEM)/phony_package.mk
BUILD_RRO_PACKAGE:= $(BUILD_SYSTEM)/build_rro_package.mk
BUILD_HOST_PREBUILT:= $(BUILD_SYSTEM)/host_prebuilt.mk
BUILD_PREBUILT:= $(BUILD_SYSTEM)/prebuilt.mk
BUILD_MULTI_PREBUILT:= $(BUILD_SYSTEM)/multi_prebuilt.mk
BUILD_JAVA_LIBRARY:= $(BUILD_SYSTEM)/java_library.mk
BUILD_STATIC_JAVA_LIBRARY:= $(BUILD_SYSTEM)/static_java_library.mk
BUILD_HOST_JAVA_LIBRARY:= $(BUILD_SYSTEM)/host_java_library.mk
BUILD_COPY_HEADERS := $(BUILD_SYSTEM)/copy_headers.mk
BUILD_NATIVE_TEST := $(BUILD_SYSTEM)/native_test.mk
BUILD_NATIVE_BENCHMARK := $(BUILD_SYSTEM)/native_benchmark.mk
BUILD_HOST_NATIVE_TEST := $(BUILD_SYSTEM)/host_native_test.mk
BUILD_FUZZ_TEST := $(BUILD_SYSTEM)/fuzz_test.mk
BUILD_HOST_FUZZ_TEST := $(BUILD_SYSTEM)/host_fuzz_test.mk

BUILD_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/shared_test_lib.mk
BUILD_HOST_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/host_shared_test_lib.mk
BUILD_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/static_test_lib.mk
BUILD_HOST_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/host_static_test_lib.mk

BUILD_NOTICE_FILE := $(BUILD_SYSTEM)/notice_files.mk
BUILD_HOST_DALVIK_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_java_library.mk
BUILD_HOST_DALVIK_STATIC_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_static_java_library.mk

BUILD_HOST_TEST_CONFIG := $(BUILD_SYSTEM)/host_test_config.mk
BUILD_TARGET_TEST_CONFIG := $(BUILD_SYSTEM)/target_test_config.mk

# ###############################################################
# Parse out any modifier targets.
# ###############################################################

hide := @

################################################################
# Tools needed in product configuration makefiles.
################################################################
NORMALIZE_PATH := build/make/tools/normalize_path.py

# $(1): the paths to be normalized
define normalize-paths
$(if $(1),$(shell $(NORMALIZE_PATH) $(1)))
endef

# ###############################################################
# Set common values
# ###############################################################

# Initialize SOONG_CONFIG_NAMESPACES so that it isn't recursive.
SOONG_CONFIG_NAMESPACES :=

# Set the extensions used for various packages
COMMON_PACKAGE_SUFFIX := .zip
COMMON_JAVA_PACKAGE_SUFFIX := .jar
COMMON_ANDROID_PACKAGE_SUFFIX := .apk

ifdef TMPDIR
JAVA_TMPDIR_ARG := -Djava.io.tmpdir=$(TMPDIR)
else
JAVA_TMPDIR_ARG :=
endif

# ###############################################################
# Include sub-configuration files
# ###############################################################

# ---------------------------------------------------------------
# Try to include buildspec.mk, which will try to set stuff up.
# If this file doesn't exist, the environment variables will
# be used, and if that doesn't work, then the default is an
# arm build
ifndef ANDROID_BUILDSPEC
ANDROID_BUILDSPEC := $(TOPDIR)buildspec.mk
endif
-include $(ANDROID_BUILDSPEC)

# ---------------------------------------------------------------
# Define most of the global variables.  These are the ones that
# are specific to the user's build configuration.
include $(BUILD_SYSTEM)/envsetup.mk

# Pruned directory options used when using findleaves.py
# See envsetup.mk for a description of SCAN_EXCLUDE_DIRS
FIND_LEAVES_EXCLUDES := $(addprefix --prune=, $(SCAN_EXCLUDE_DIRS) .repo .git)

# The build system exposes several variables for where to find the kernel
# headers:
#   TARGET_DEVICE_KERNEL_HEADERS is automatically created for the current
#       device being built. It is set as $(TARGET_DEVICE_DIR)/kernel-headers,
#       e.g. device/samsung/tuna/kernel-headers. This directory is not
#       explicitly set by anyone, the build system always adds this subdir.
#
#   TARGET_BOARD_KERNEL_HEADERS is specified by the BoardConfig.mk file
#       to allow other directories to be included. This is useful if there's
#       some common place where a few headers are being kept for a group
#       of devices. For example, device/<vendor>/common/kernel-headers could
#       contain some headers for several of <vendor>'s devices.
#
#   TARGET_PRODUCT_KERNEL_HEADERS is generated by the product inheritance
#       graph. This allows architecture products to provide headers for the
#       devices using that architecture. For example,
#       hardware/ti/omap4xxx/omap4.mk will specify
#       PRODUCT_VENDOR_KERNEL_HEADERS variable that specify where the omap4
#       specific headers are, e.g. hardware/ti/omap4xxx/kernel-headers.
#       The build system then combines all the values specified by all the
#       PRODUCT_VENDOR_KERNEL_HEADERS directives in the product inheritance
#       tree and then exports a TARGET_PRODUCT_KERNEL_HEADERS variable.
#
# The layout of subdirs in any of the kernel-headers dir should mirror the
# layout of the kernel include/ directory. For example,
#     device/samsung/tuna/kernel-headers/linux/,
#     hardware/ti/omap4xxx/kernel-headers/media/,
#     etc.
#
# NOTE: These directories MUST contain post-processed headers using the
# bionic/libc/kernel/tools/clean_header.py tool. Additionally, the original
# kernel headers must also be checked in, but in a different subdirectory. By
# convention, the originals should be checked into original-kernel-headers
# directory of the same parent dir. For example,
#     device/samsung/tuna/kernel-headers            <----- post-processed
#     device/samsung/tuna/original-kernel-headers   <----- originals
#
TARGET_DEVICE_KERNEL_HEADERS := $(strip $(wildcard $(TARGET_DEVICE_DIR)/kernel-headers))

define validate-kernel-headers
$(if $(firstword $(foreach hdr_dir,$(1),\
         $(filter-out kernel-headers,$(notdir $(hdr_dir))))),\
     $(error Kernel header dirs must be end in kernel-headers: $(1)))
endef
# also allow the board config to provide additional directories since
# there could be device/oem/base_hw and device/oem/derived_hw
# that both are valid devices but derived_hw needs to use kernel headers
# from base_hw.
TARGET_BOARD_KERNEL_HEADERS := $(strip $(wildcard $(TARGET_BOARD_KERNEL_HEADERS)))
TARGET_BOARD_KERNEL_HEADERS := $(patsubst %/,%,$(TARGET_BOARD_KERNEL_HEADERS))
$(call validate-kernel-headers,$(TARGET_BOARD_KERNEL_HEADERS))

# then add product-inherited includes, to allow for
# hardware/sivendor/chip/chip.mk to include their own headers
TARGET_PRODUCT_KERNEL_HEADERS := $(strip $(wildcard $(PRODUCT_VENDOR_KERNEL_HEADERS)))
TARGET_PRODUCT_KERNEL_HEADERS := $(patsubst %/,%,$(TARGET_PRODUCT_KERNEL_HEADERS))
$(call validate-kernel-headers,$(TARGET_PRODUCT_KERNEL_HEADERS))
.KATI_READONLY := TARGET_DEVICE_KERNEL_HEADERS TARGET_BOARD_KERNEL_HEADERS TARGET_PRODUCT_KERNEL_HEADERS

# Commands to generate .toc file common to ELF .so files.
define _gen_toc_command_for_elf
$(hide) ($($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) -d $(1) | grep SONAME || echo "No SONAME for $1") > $(2)
$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) --dyn-syms $(1) | awk '{$$2=""; $$3=""; print}' >> $(2)
endef

# Commands to generate .toc file from Darwin dynamic library.
define _gen_toc_command_for_macho
$(hide) $(HOST_OTOOL) -l $(1) | grep LC_ID_DYLIB -A 5 > $(2)
$(hide) $(HOST_NM) -gP $(1) | cut -f1-2 -d" " | (grep -v U$$ >> $(2) || true)
endef

ifeq ($(CALLED_FROM_SETUP),true)
include $(BUILD_SYSTEM)/ccache.mk
include $(BUILD_SYSTEM)/goma.mk
endif

ifdef TARGET_PREFER_32_BIT
TARGET_PREFER_32_BIT_APPS := true
TARGET_PREFER_32_BIT_EXECUTABLES := true
endif

# GCC version selection
TARGET_GCC_VERSION := 4.9
ifdef TARGET_2ND_ARCH
2ND_TARGET_GCC_VERSION := 4.9
endif

# Normalize WITH_STATIC_ANALYZER
ifeq ($(strip $(WITH_STATIC_ANALYZER)),0)
  WITH_STATIC_ANALYZER :=
endif

# Unset WITH_TIDY_ONLY if global WITH_TIDY_ONLY is not true nor 1.
ifeq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
  WITH_TIDY_ONLY :=
endif

# Pick a Java compiler.
include $(BUILD_SYSTEM)/combo/javac.mk

# ---------------------------------------------------------------
# Check that the configuration is current.  We check that
# BUILD_ENV_SEQUENCE_NUMBER is current against this value.
# Don't fail if we're called from envsetup, so they have a
# chance to update their environment.

ifeq (,$(strip $(CALLED_FROM_SETUP)))
ifneq (,$(strip $(BUILD_ENV_SEQUENCE_NUMBER)))
ifneq ($(BUILD_ENV_SEQUENCE_NUMBER),$(CORRECT_BUILD_ENV_SEQUENCE_NUMBER))
$(warning BUILD_ENV_SEQUENCE_NUMBER is set incorrectly.)
$(info *** If you use envsetup/lunch/choosecombo:)
$(info ***   - Re-execute envsetup (". envsetup.sh"))
$(info ***   - Re-run lunch or choosecombo)
$(info *** If you use buildspec.mk:)
$(info ***   - Look at buildspec.mk.default to see what has changed)
$(info ***   - Update BUILD_ENV_SEQUENCE_NUMBER to "$(CORRECT_BUILD_ENV_SEQUENCE_NUMBER)")
$(error bailing..)
endif
endif
endif

# Set up PDK so we can use TARGET_BUILD_PDK to select prebuilt tools below
.PHONY: pdk fusion
pdk fusion: $(DEFAULT_GOAL)

# What to build:
# pdk fusion if:
# 1) PDK_FUSION_PLATFORM_ZIP / PDK_FUSION_PLATFORM_DIR is passed in from the environment
# or
# 2) the platform.zip / pdk.mk exists in the default location
# or
# 3) fusion is a command line build goal,
#    PDK_FUSION_PLATFORM_ZIP is needed anyway, then do we need the 'fusion' goal?
# otherwise pdk only if:
# 1) pdk is a command line build goal
# or
# 2) TARGET_BUILD_PDK is passed in from the environment

# if PDK_FUSION_PLATFORM_ZIP or PDK_FUSION_PLATFORM_DIR is specified, do not override.
ifeq (,$(strip $(PDK_FUSION_PLATFORM_ZIP)$(PDK_FUSION_PLATFORM_DIR)))
  # Most PDK project paths should be using vendor/pdk/TARGET_DEVICE
  # but some legacy ones (e.g. mini_armv7a_neon generic PDK) were setup
  # with vendor/pdk/TARGET_PRODUCT.
  # Others are set up with vendor/pdk/TARGET_DEVICE/TARGET_DEVICE-userdebug
  _pdk_fusion_search_paths := \
    vendor/pdk/$(TARGET_DEVICE)/$(TARGET_DEVICE)-$(TARGET_BUILD_VARIANT)/platform \
    vendor/pdk/$(TARGET_DEVICE)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)/platform \
    vendor/pdk/$(TARGET_DEVICE)/$(patsubst aosp_%,full_%,$(TARGET_PRODUCT))-$(TARGET_BUILD_VARIANT)/platform \
    vendor/pdk/$(TARGET_PRODUCT)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)/platform \
    vendor/pdk/$(TARGET_PRODUCT)/$(patsubst aosp_%,full_%,$(TARGET_PRODUCT))-$(TARGET_BUILD_VARIANT)/platform

  _pdk_fusion_default_platform_zip := $(strip $(foreach p,$(_pdk_fusion_search_paths),$(wildcard $(p)/platform.zip)))
  ifneq (,$(_pdk_fusion_default_platform_zip))
    PDK_FUSION_PLATFORM_ZIP := $(word 1, $(_pdk_fusion_default_platform_zip))
    _pdk_fusion_default_platform_zip :=
  else
    _pdk_fusion_default_platform_mk := $(strip $(foreach p,$(_pdk_fusion_search_paths),$(wildcard $(p)/pdk.mk)))
    ifneq (,$(_pdk_fusion_default_platform_mk))
      PDK_FUSION_PLATFORM_DIR := $(dir $(word 1,$(_pdk_fusion_default_platform_mk)))
      _pdk_fusion_default_platform_mk :=
    endif
  endif # _pdk_fusion_default_platform_zip
  _pdk_fusion_search_paths :=
endif # !PDK_FUSION_PLATFORM_ZIP && !PDK_FUSION_PLATFORM_DIR

ifneq (,$(PDK_FUSION_PLATFORM_ZIP))
  ifneq (,$(PDK_FUSION_PLATFORM_DIR))
    $(error Only one of PDK_FUSION_PLATFORM_ZIP or PDK_FUSION_PLATFORM_DIR may be specified)
  endif
endif

ifneq (,$(filter pdk fusion, $(MAKECMDGOALS)))
TARGET_BUILD_PDK := true
ifneq (,$(filter fusion, $(MAKECMDGOALS)))
ifeq (,$(strip $(PDK_FUSION_PLATFORM_ZIP)$(PDK_FUSION_PLATFORM_DIR)))
  $(error Specify PDK_FUSION_PLATFORM_ZIP or PDK_FUSION_PLATFORM_DIR to do a PDK fusion.)
endif
endif  # fusion
endif  # pdk or fusion

ifdef PDK_FUSION_PLATFORM_ZIP
TARGET_BUILD_PDK := true
ifeq (,$(wildcard $(PDK_FUSION_PLATFORM_ZIP)))
  ifneq (,$(wildcard $(patsubst %.zip,%,$(PDK_FUSION_PLATFORM_ZIP))/pdk.mk))
    PDK_FUSION_PLATFORM_DIR := $(patsubst %.zip,%,$(PDK_FUSION_PLATFORM_ZIP))
    PDK_FUSION_PLATFORM_ZIP :=
  else
    $(error Cannot find file $(PDK_FUSION_PLATFORM_ZIP).)
  endif
endif
endif

ifdef PDK_FUSION_PLATFORM_DIR
TARGET_BUILD_PDK := true
ifeq (,$(wildcard $(PDK_FUSION_PLATFORM_DIR)/pdk.mk))
  $(error Cannot find file $(PDK_FUSION_PLATFORM_DIR)/pdk.mk.)
endif
endif

BUILD_PLATFORM_ZIP := $(filter platform platform-java,$(MAKECMDGOALS))

# ---------------------------------------------------------------
# Whether we can expect a full build graph
ALLOW_MISSING_DEPENDENCIES := $(filter true,$(ALLOW_MISSING_DEPENDENCIES))
ifneq ($(TARGET_BUILD_APPS),)
ALLOW_MISSING_DEPENDENCIES := true
endif
ifeq ($(TARGET_BUILD_PDK),true)
ALLOW_MISSING_DEPENDENCIES := true
endif
ifneq ($(filter true,$(SOONG_ALLOW_MISSING_DEPENDENCIES)),)
ALLOW_MISSING_DEPENDENCIES := true
endif
.KATI_READONLY := ALLOW_MISSING_DEPENDENCIES

TARGET_BUILD_APPS_USE_PREBUILT_SDK :=
ifdef TARGET_BUILD_APPS
  ifndef UNBUNDLED_BUILD_SDKS_FROM_SOURCE
    TARGET_BUILD_APPS_USE_PREBUILT_SDK := true
  endif
endif

prebuilt_sdk_tools := prebuilts/sdk/tools
prebuilt_sdk_tools_bin := $(prebuilt_sdk_tools)/$(HOST_OS)/bin

# Always use prebuilts for ckati and makeparallel
prebuilt_build_tools := prebuilts/build-tools
prebuilt_build_tools_wrappers := prebuilts/build-tools/common/bin
prebuilt_build_tools_jars := prebuilts/build-tools/common/framework
prebuilt_build_tools_bin_noasan := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/bin
ifeq ($(filter address,$(SANITIZE_HOST)),)
prebuilt_build_tools_bin := $(prebuilt_build_tools_bin_noasan)
else
prebuilt_build_tools_bin := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/asan/bin
endif

USE_PREBUILT_SDK_TOOLS_IN_PLACE := true

# Work around for b/68406220
# This should match the soong version.
USE_D8 := true
.KATI_READONLY := USE_D8

#
# Tools that are prebuilts for TARGET_BUILD_APPS
#
ifeq (,$(TARGET_BUILD_APPS)$(filter true,$(TARGET_BUILD_PDK)))
  AIDL := $(HOST_OUT_EXECUTABLES)/aidl
  AAPT := $(HOST_OUT_EXECUTABLES)/aapt
  AAPT2 := $(HOST_OUT_EXECUTABLES)/aapt2
  MAINDEXCLASSES := $(HOST_OUT_EXECUTABLES)/mainDexClasses
  SIGNAPK_JAR := $(HOST_OUT_JAVA_LIBRARIES)/signapk$(COMMON_JAVA_PACKAGE_SUFFIX)
  SIGNAPK_JNI_LIBRARY_PATH := $(HOST_OUT_SHARED_LIBRARIES)
  ZIPALIGN := $(HOST_OUT_EXECUTABLES)/zipalign

else # TARGET_BUILD_APPS || TARGET_BUILD_PDK
  AIDL := $(prebuilt_build_tools_bin)/aidl
  AAPT := $(prebuilt_sdk_tools_bin)/aapt
  AAPT2 := $(prebuilt_sdk_tools_bin)/aapt2
  MAINDEXCLASSES := $(prebuilt_sdk_tools)/mainDexClasses
  SIGNAPK_JAR := $(prebuilt_sdk_tools)/lib/signapk$(COMMON_JAVA_PACKAGE_SUFFIX)
  SIGNAPK_JNI_LIBRARY_PATH := $(prebuilt_sdk_tools)/$(HOST_OS)/lib64
  ZIPALIGN := $(prebuilt_build_tools_bin)/zipalign
endif # TARGET_BUILD_APPS || TARGET_BUILD_PDK

ifeq (,$(TARGET_BUILD_APPS))
  # Use RenderScript prebuilts for unbundled builds but not PDK builds
  LLVM_RS_CC := $(HOST_OUT_EXECUTABLES)/llvm-rs-cc
  BCC_COMPAT := $(HOST_OUT_EXECUTABLES)/bcc_compat
else
  LLVM_RS_CC := $(prebuilt_sdk_tools_bin)/llvm-rs-cc
  BCC_COMPAT := $(prebuilt_sdk_tools_bin)/bcc_compat
endif # TARGET_BUILD_PDK

prebuilt_sdk_tools :=
prebuilt_sdk_tools_bin :=

ACP := $(prebuilt_build_tools_bin)/acp
CKATI := $(prebuilt_build_tools_bin)/ckati
DEPMOD := $(HOST_OUT_EXECUTABLES)/depmod
FILESLIST := $(SOONG_HOST_OUT_EXECUTABLES)/fileslist
HOST_INIT_VERIFIER := $(HOST_OUT_EXECUTABLES)/host_init_verifier
MAKEPARALLEL := $(prebuilt_build_tools_bin)/makeparallel
SOONG_JAVAC_WRAPPER := $(SOONG_HOST_OUT_EXECUTABLES)/soong_javac_wrapper
SOONG_ZIP := $(SOONG_HOST_OUT_EXECUTABLES)/soong_zip
MERGE_ZIPS := $(SOONG_HOST_OUT_EXECUTABLES)/merge_zips
XMLLINT := $(SOONG_HOST_OUT_EXECUTABLES)/xmllint
ZIP2ZIP := $(SOONG_HOST_OUT_EXECUTABLES)/zip2zip
ZIPTIME := $(prebuilt_build_tools_bin)/ziptime

# ---------------------------------------------------------------
# Generic tools.

LEX := $(prebuilt_build_tools_bin_noasan)/flex
# The default PKGDATADIR built in the prebuilt bison is a relative path
# prebuilts/build-tools/common/bison.
# To run bison from elsewhere you need to set up enviromental variable
# BISON_PKGDATADIR.
BISON_PKGDATADIR := $(PWD)/prebuilts/build-tools/common/bison
BISON := $(prebuilt_build_tools_bin_noasan)/bison
YACC := $(BISON) -d
BISON_DATA := $(wildcard $(BISON_PKGDATADIR)/* $(BISON_PKGDATADIR)/*/*)

YASM := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/yasm/yasm

DOXYGEN:= doxygen
ifeq ($(HOST_OS),linux)
BREAKPAD_DUMP_SYMS := $(HOST_OUT_EXECUTABLES)/dump_syms
else
# For non-supported hosts, do not generate breakpad symbols.
BREAKPAD_GENERATE_SYMBOLS := false
endif
PROTOC := $(HOST_OUT_EXECUTABLES)/aprotoc$(HOST_EXECUTABLE_SUFFIX)
NANOPB_SRCS := $(HOST_OUT_EXECUTABLES)/protoc-gen-nanopb
VTSC := $(HOST_OUT_EXECUTABLES)/vtsc$(HOST_EXECUTABLE_SUFFIX)
MKBOOTFS := $(HOST_OUT_EXECUTABLES)/mkbootfs$(HOST_EXECUTABLE_SUFFIX)
MINIGZIP := $(HOST_OUT_EXECUTABLES)/minigzip$(HOST_EXECUTABLE_SUFFIX)
BROTLI := $(HOST_OUT_EXECUTABLES)/brotli$(HOST_EXECUTABLE_SUFFIX)
ifeq (,$(strip $(BOARD_CUSTOM_MKBOOTIMG)))
MKBOOTIMG := $(HOST_OUT_EXECUTABLES)/mkbootimg$(HOST_EXECUTABLE_SUFFIX)
else
MKBOOTIMG := $(BOARD_CUSTOM_MKBOOTIMG)
endif
ifeq (,$(strip $(BOARD_CUSTOM_BPTTOOL)))
BPTTOOL := $(HOST_OUT_EXECUTABLES)/bpttool$(HOST_EXECUTABLE_SUFFIX)
else
BPTTOOL := $(BOARD_CUSTOM_BPTTOOL)
endif
ifeq (,$(strip $(BOARD_CUSTOM_AVBTOOL)))
AVBTOOL := $(HOST_OUT_EXECUTABLES)/avbtool$(HOST_EXECUTABLE_SUFFIX)
else
AVBTOOL := $(BOARD_CUSTOM_AVBTOOL)
endif
APICHECK := $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX)
FS_GET_STATS := $(HOST_OUT_EXECUTABLES)/fs_get_stats$(HOST_EXECUTABLE_SUFFIX)
MAKE_EXT4FS := $(HOST_OUT_EXECUTABLES)/mke2fs$(HOST_EXECUTABLE_SUFFIX)
MKEXTUSERIMG := $(HOST_OUT_EXECUTABLES)/mkuserimg_mke2fs
MKE2FS_CONF := system/extras/ext4_utils/mke2fs.conf
BLK_ALLOC_TO_BASE_FS := $(HOST_OUT_EXECUTABLES)/blk_alloc_to_base_fs$(HOST_EXECUTABLE_SUFFIX)
MAKE_SQUASHFS := $(HOST_OUT_EXECUTABLES)/mksquashfs$(HOST_EXECUTABLE_SUFFIX)
MKSQUASHFSUSERIMG := $(HOST_OUT_EXECUTABLES)/mksquashfsimage.sh
MAKE_F2FS := $(HOST_OUT_EXECUTABLES)/make_f2fs$(HOST_EXECUTABLE_SUFFIX)
MKF2FSUSERIMG := $(HOST_OUT_EXECUTABLES)/mkf2fsuserimg.sh
SIMG2IMG := $(HOST_OUT_EXECUTABLES)/simg2img$(HOST_EXECUTABLE_SUFFIX)
IMG2SIMG := $(HOST_OUT_EXECUTABLES)/img2simg$(HOST_EXECUTABLE_SUFFIX)
E2FSCK := $(HOST_OUT_EXECUTABLES)/e2fsck$(HOST_EXECUTABLE_SUFFIX)
MKTARBALL := build/make/tools/mktarball.sh
TUNE2FS := $(HOST_OUT_EXECUTABLES)/tune2fs$(HOST_EXECUTABLE_SUFFIX)
JARJAR := $(HOST_OUT_JAVA_LIBRARIES)/jarjar.jar
DATA_BINDING_COMPILER := $(HOST_OUT_JAVA_LIBRARIES)/databinding-compiler.jar
FAT16COPY := build/make/tools/fat16copy.py
CHECK_LINK_TYPE := build/make/tools/check_link_type.py
CHECK_ELF_FILE := build/make/tools/check_elf_file.py
LPMAKE := $(HOST_OUT_EXECUTABLES)/lpmake$(HOST_EXECUTABLE_SUFFIX)
BUILD_SUPER_IMAGE := build/make/tools/releasetools/build_super_image.py

PROGUARD_HOME := external/proguard
PROGUARD := $(PROGUARD_HOME)/bin/proguard.sh
PROGUARD_DEPS := $(PROGUARD) $(PROGUARD_HOME)/lib/proguard.jar
JAVATAGS := build/make/tools/java-event-log-tags.py
MERGETAGS := build/make/tools/merge-event-log-tags.py
BUILD_IMAGE_SRCS := $(wildcard build/make/tools/releasetools/*.py)
APPEND2SIMG := $(HOST_OUT_EXECUTABLES)/append2simg
VERITY_SIGNER := $(HOST_OUT_EXECUTABLES)/verity_signer
BUILD_VERITY_METADATA := $(HOST_OUT_EXECUTABLES)/build_verity_metadata.py
BUILD_VERITY_TREE := $(HOST_OUT_EXECUTABLES)/build_verity_tree
BOOT_SIGNER := $(HOST_OUT_EXECUTABLES)/boot_signer
FUTILITY := $(HOST_OUT_EXECUTABLES)/futility-host
VBOOT_SIGNER := prebuilts/misc/scripts/vboot_signer/vboot_signer.sh
FEC := $(HOST_OUT_EXECUTABLES)/fec
BRILLO_UPDATE_PAYLOAD := $(HOST_OUT_EXECUTABLES)/brillo_update_payload

DEXDUMP := $(HOST_OUT_EXECUTABLES)/dexdump2$(BUILD_EXECUTABLE_SUFFIX)
PROFMAN := $(HOST_OUT_EXECUTABLES)/profman

FINDBUGS_DIR := external/owasp/sanitizer/tools/findbugs/bin
FINDBUGS := $(FINDBUGS_DIR)/findbugs

JETIFIER := prebuilts/sdk/tools/jetifier/jetifier-standalone/bin/jetifier-standalone

EXTRACT_KERNEL := build/make/tools/extract_kernel.py

USE_OPENJDK9 := true

ifeq ($(EXPERIMENTAL_USE_OPENJDK9),)
TARGET_OPENJDK9 :=
else ifeq ($(EXPERIMENTAL_USE_OPENJDK9),1.8)
TARGET_OPENJDK9 :=
else ifeq ($(EXPERIMENTAL_USE_OPENJDK9),true)
TARGET_OPENJDK9 := true
endif

# Path to tools.jar
HOST_JDK_TOOLS_JAR := $(ANDROID_JAVA8_HOME)/lib/tools.jar

# It's called md5 on Mac OS and md5sum on Linux
ifeq ($(HOST_OS),darwin)
MD5SUM:=md5 -q
else
MD5SUM:=md5sum
endif

APICHECK_COMMAND := $(JAVA) -Xmx4g -jar $(APICHECK) --no-banner --compatible-output=yes

# Boolean variable determining if the whitelist for compatible properties is enabled
PRODUCT_COMPATIBLE_PROPERTY := false
ifneq ($(PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE),)
  PRODUCT_COMPATIBLE_PROPERTY := $(PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE)
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  #$(warning no product shipping level defined)
else ifneq ($(call math_lt,27,$(PRODUCT_SHIPPING_API_LEVEL)),)
  PRODUCT_COMPATIBLE_PROPERTY := true
endif

.KATI_READONLY := \
    PRODUCT_COMPATIBLE_PROPERTY

# Boolean variable determining if Treble is fully enabled
PRODUCT_FULL_TREBLE := false
ifneq ($(PRODUCT_FULL_TREBLE_OVERRIDE),)
  PRODUCT_FULL_TREBLE := $(PRODUCT_FULL_TREBLE_OVERRIDE)
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  #$(warning no product shipping level defined)
else ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),26),)
  PRODUCT_FULL_TREBLE := true
endif

# TODO(b/69865032): Make PRODUCT_NOTICE_SPLIT the default behavior and remove
#    references to it here and below.
ifdef PRODUCT_NOTICE_SPLIT_OVERRIDE
   $(error PRODUCT_NOTICE_SPLIT_OVERRIDE cannot be set.)
endif

requirements := \
    PRODUCT_TREBLE_LINKER_NAMESPACES \
    PRODUCT_SEPOLICY_SPLIT \
    PRODUCT_ENFORCE_VINTF_MANIFEST \
    PRODUCT_NOTICE_SPLIT

# If it is overriden, then the requirement override is taken, otherwise it's
# PRODUCT_FULL_TREBLE
$(foreach req,$(requirements),$(eval \
    $(req) := $(if $($(req)_OVERRIDE),$($(req)_OVERRIDE),$(PRODUCT_FULL_TREBLE))))
# If the requirement is false for any reason, then it's not PRODUCT_FULL_TREBLE
$(foreach req,$(requirements),$(eval \
    PRODUCT_FULL_TREBLE := $(if $(filter false,$($(req))),false,$(PRODUCT_FULL_TREBLE))))

PRODUCT_FULL_TREBLE_OVERRIDE ?=
$(foreach req,$(requirements),$(eval $(req)_OVERRIDE ?=))

# TODO(b/114488870): disallow PRODUCT_FULL_TREBLE_OVERRIDE from being used.
.KATI_READONLY := \
    PRODUCT_FULL_TREBLE_OVERRIDE \
    $(foreach req,$(requirements),$(req)_OVERRIDE) \
    $(requirements) \
    PRODUCT_FULL_TREBLE \

$(KATI_obsolete_var $(foreach req,$(requirements),$(req)_OVERRIDE) \
    ,This should be referenced without the _OVERRIDE suffix.)

requirements :=

# BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED can be true only if early-mount of
# partitions is supported. But the early-mount must be supported for full
# treble products, and so BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED should be set
# by default for full treble products.
ifeq ($(PRODUCT_FULL_TREBLE),true)
  BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED ?= true
endif

# If PRODUCT_USE_VNDK is true and BOARD_VNDK_VERSION is not defined yet,
# BOARD_VNDK_VERSION will be set to "current" as default.
# PRODUCT_USE_VNDK will be true in Android-P or later launching devices.
PRODUCT_USE_VNDK := false
ifneq ($(PRODUCT_USE_VNDK_OVERRIDE),)
  PRODUCT_USE_VNDK := $(PRODUCT_USE_VNDK_OVERRIDE)
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  # No shipping level defined
else ifeq ($(call math_gt_or_eq,27,$(PRODUCT_SHIPPING_API_LEVEL)),)
  PRODUCT_USE_VNDK := $(PRODUCT_FULL_TREBLE)
endif

ifeq ($(PRODUCT_USE_VNDK),true)
  ifndef BOARD_VNDK_VERSION
    BOARD_VNDK_VERSION := current
  endif
endif

$(KATI_obsolete_var PRODUCT_USE_VNDK_OVERRIDE,Use PRODUCT_USE_VNDK instead)
.KATI_READONLY := \
    PRODUCT_USE_VNDK

# Set BOARD_SYSTEMSDK_VERSIONS to the latest SystemSDK version starting from P-launching
# devices if unset.
ifndef BOARD_SYSTEMSDK_VERSIONS
  ifdef PRODUCT_SHIPPING_API_LEVEL
  ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),28),)
    ifeq (REL,$(PLATFORM_VERSION_CODENAME))
      BOARD_SYSTEMSDK_VERSIONS := $(PLATFORM_SDK_VERSION)
    else
      BOARD_SYSTEMSDK_VERSIONS := $(PLATFORM_VERSION_CODENAME)
    endif
  endif
  endif
endif


ifdef PRODUCT_SHIPPING_API_LEVEL
  ifneq ($(call numbers_less_than,$(PRODUCT_SHIPPING_API_LEVEL),$(BOARD_SYSTEMSDK_VERSIONS)),)
    $(error BOARD_SYSTEMSDK_VERSIONS ($(BOARD_SYSTEMSDK_VERSIONS)) must all be greater than or equal to PRODUCT_SHIPPING_API_LEVEL ($(PRODUCT_SHIPPING_API_LEVEL)))
  endif
  ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),28),)
    ifneq ($(TARGET_IS_64_BIT), true)
      ifneq ($(TARGET_USES_64_BIT_BINDER), true)
        $(error When PRODUCT_SHIPPING_API_LEVEL >= 28, TARGET_USES_64_BIT_BINDER must be true)
      endif
    endif
  endif
  ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),29),)
    ifneq ($(BOARD_OTA_FRAMEWORK_VBMETA_VERSION_OVERRIDE),)
      $(error When PRODUCT_SHIPPING_API_LEVEL >= 29, BOARD_OTA_FRAMEWORK_VBMETA_VERSION_OVERRIDE cannot be set)
    endif
  endif
endif

# The default key if not set as LOCAL_CERTIFICATE
ifdef PRODUCT_DEFAULT_DEV_CERTIFICATE
  DEFAULT_SYSTEM_DEV_CERTIFICATE := $(PRODUCT_DEFAULT_DEV_CERTIFICATE)
else
  DEFAULT_SYSTEM_DEV_CERTIFICATE := build/target/product/security/testkey
endif
.KATI_READONLY := DEFAULT_SYSTEM_DEV_CERTIFICATE

BUILD_NUMBER_FROM_FILE := $$(cat $(OUT_DIR)/build_number.txt)
BUILD_DATETIME_FROM_FILE := $$(cat $(BUILD_DATETIME_FILE))

# SEPolicy versions

# PLATFORM_SEPOLICY_VERSION is a number of the form "NN.m" with "NN" mapping to
# PLATFORM_SDK_VERSION and "m" as a minor number which allows for SELinux
# changes independent of PLATFORM_SDK_VERSION.  This value will be set to
# 10000.0 to represent tip-of-tree development that is inherently unstable and
# thus designed not to work with any shipping vendor policy.  This is similar in
# spirit to how DEFAULT_APP_TARGET_SDK is set.
# The minor version ('m' component) must be updated every time a platform release
# is made which breaks compatibility with the previous platform sepolicy version,
# not just on every increase in PLATFORM_SDK_VERSION.  The minor version should
# be reset to 0 on every bump of the PLATFORM_SDK_VERSION.
sepolicy_major_vers := 29
sepolicy_minor_vers := 0

ifneq ($(sepolicy_major_vers), $(PLATFORM_SDK_VERSION))
$(error sepolicy_major_version does not match PLATFORM_SDK_VERSION, please update.)
endif

TOT_SEPOLICY_VERSION := 10000.0
ifneq (REL,$(PLATFORM_VERSION_CODENAME))
    PLATFORM_SEPOLICY_VERSION := $(TOT_SEPOLICY_VERSION)
else
    PLATFORM_SEPOLICY_VERSION := $(join $(addsuffix .,$(sepolicy_major_vers)), $(sepolicy_minor_vers))
endif
sepolicy_major_vers :=
sepolicy_minor_vers :=

# A list of SEPolicy versions, besides PLATFORM_SEPOLICY_VERSION, that the framework supports.
PLATFORM_SEPOLICY_COMPAT_VERSIONS := \
    26.0 \
    27.0 \
    28.0 \

.KATI_READONLY := \
    PLATFORM_SEPOLICY_COMPAT_VERSIONS \
    PLATFORM_SEPOLICY_VERSION \
    TOT_SEPOLICY_VERSION \

ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)
  ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
    $(error PRODUCT_USE_DYNAMIC_PARTITIONS must be true when PRODUCT_RETROFIT_DYNAMIC_PARTITIONS \
        is set)
  endif
  ifdef PRODUCT_SHIPPING_API_LEVEL
    ifeq (true,$(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),29))
      $(error Devices with shipping API level $(PRODUCT_SHIPPING_API_LEVEL) must not set \
          PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)
    endif
  endif
endif

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
    ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
        $(error BOARD_BUILD_SYSTEM_ROOT_IMAGE cannot be true for devices with dynamic partitions)
    endif
    ifneq ($(PRODUCT_USE_DYNAMIC_PARTITION_SIZE),true)
        $(error PRODUCT_USE_DYNAMIC_PARTITION_SIZE must be true for devices with dynamic partitions)
    endif
endif

ifeq ($(PRODUCT_BUILD_SUPER_PARTITION),true)
    ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
        $(error Can only build super partition for devices with dynamic partitions)
    endif
endif


ifeq ($(PRODUCT_USE_DYNAMIC_PARTITION_SIZE),true)

ifneq ($(BOARD_SYSTEMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_SYSTEMIMAGE_PARTITION_SIZE and \
    BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_VENDORIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_VENDORIMAGE_PARTITION_SIZE and \
    BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_ODMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_ODMIMAGE_PARTITION_SIZE and \
    BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_PRODUCTIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_PRODUCTIMAGE_PARTITION_SIZE and \
    BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_PRODUCT_SERVICESIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_PRODUCT_SERVICESIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_PRODUCT_SERVICESIMAGE_PARTITION_SIZE and \
    BOARD_PRODUCT_SERVICESIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

endif # PRODUCT_USE_DYNAMIC_PARTITION_SIZE

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)

# BOARD_SUPER_PARTITION_GROUPS defines a list of "updatable groups". Each updatable group is a
# group of partitions that share the same pool of free spaces.
# For each group in BOARD_SUPER_PARTITION_GROUPS, a BOARD_{GROUP}_SIZE and
# BOARD_{GROUP}_PARTITION_PARTITION_LIST may be defined.
#     - BOARD_{GROUP}_SIZE: The maximum sum of sizes of all partitions in the group.
#       Must not be empty.
#     - BOARD_{GROUP}_PARTITION_PARTITION_LIST: the list of partitions that belongs to this group.
#       If empty, no partitions belong to this group, and the sum of sizes is effectively 0.
$(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)), \
    $(eval BOARD_$(group)_PARTITION_LIST ?=) \
    $(eval .KATI_READONLY := BOARD_$(group)_PARTITION_LIST) \
)
ifeq ($(PRODUCT_BUILD_SUPER_PARTITION),true)
$(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)), \
    $(eval BOARD_$(group)_SIZE := $(strip $(BOARD_$(group)_SIZE))) \
    $(if $(BOARD_$(group)_SIZE),,$(error BOARD_$(group)_SIZE must not be empty)) \
    $(eval .KATI_READONLY := BOARD_$(group)_SIZE) \
)
endif # PRODUCT_BUILD_SUPER_PARTITION

# BOARD_*_PARTITION_LIST: a list of the following tokens
valid_super_partition_list := system vendor product product_services odm
$(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)), \
    $(if $(filter-out $(valid_super_partition_list),$(BOARD_$(group)_PARTITION_LIST)), \
        $(error BOARD_$(group)_PARTITION_LIST contains invalid partition name \
            $(filter-out $(valid_super_partition_list),$(BOARD_$(group)_PARTITION_LIST)). \
            Valid names are $(valid_super_partition_list))))
valid_super_partition_list :=


# Define BOARD_SUPER_PARTITION_PARTITION_LIST, the sum of all BOARD_*_PARTITION_LIST
ifdef BOARD_SUPER_PARTITION_PARTITION_LIST
$(error BOARD_SUPER_PARTITION_PARTITION_LIST should not be defined, but computed from \
    BOARD_SUPER_PARTITION_GROUPS and BOARD_*_PARTITION_LIST)
endif
BOARD_SUPER_PARTITION_PARTITION_LIST := \
    $(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)), \
        $(BOARD_$(group)_PARTITION_LIST))
.KATI_READONLY := BOARD_SUPER_PARTITION_PARTITION_LIST

endif # PRODUCT_USE_DYNAMIC_PARTITIONS

ifeq ($(PRODUCT_BUILD_SUPER_PARTITION),true)

ifneq ($(BOARD_SUPER_PARTITION_SIZE),)
ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)

# The metadata device must be specified manually for retrofitting.
ifeq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),)
$(error Must specify BOARD_SUPER_PARTITION_METADATA_DEVICE if PRODUCT_RETROFIT_DYNAMIC_PARTITIONS=true.)
endif

# The super partition block device list must be specified manually for retrofitting.
ifeq ($(BOARD_SUPER_PARTITION_BLOCK_DEVICES),)
$(error Must specify BOARD_SUPER_PARTITION_BLOCK_DEVICES if PRODUCT_RETROFIT_DYNAMIC_PARTITIONS=true.)
endif

# The metadata device must be included in the super partition block device list.
ifeq (,$(filter $(BOARD_SUPER_PARTITION_METADATA_DEVICE),$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)))
$(error BOARD_SUPER_PARTITION_METADATA_DEVICE is not listed in BOARD_SUPER_PARTITION_BLOCK_DEVICES.)
endif

# The metadata device must be supplied to init via the kernel command-line.
INTERNAL_KERNEL_CMDLINE += androidboot.super_partition=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)

BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE := true

# If "vendor" is listed as one of the dynamic partitions but without its image available (e.g. an
# AOSP target built without vendor image), don't build the retrofit full OTA package. Because we
# won't be able to build meaningful super_* images for retrofitting purpose.
ifneq (,$(filter vendor,$(BOARD_SUPER_PARTITION_PARTITION_LIST)))
ifndef BUILDING_VENDOR_IMAGE
ifndef BOARD_PREBUILT_VENDORIMAGE
BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE :=
endif # BOARD_PREBUILT_VENDORIMAGE
endif # BUILDING_VENDOR_IMAGE
endif # BOARD_SUPER_PARTITION_PARTITION_LIST

else # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS

# For normal devices, we populate BOARD_SUPER_PARTITION_BLOCK_DEVICES so the
# build can handle both cases consistently.
ifeq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),)
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
endif

ifeq ($(BOARD_SUPER_PARTITION_BLOCK_DEVICES),)
BOARD_SUPER_PARTITION_BLOCK_DEVICES := $(BOARD_SUPER_PARTITION_METADATA_DEVICE)
endif

# If only one super block device, default to super partition size.
ifeq ($(word 2,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)),)
BOARD_SUPER_PARTITION_$(call to-upper,$(strip $(BOARD_SUPER_PARTITION_BLOCK_DEVICES)))_DEVICE_SIZE ?= \
    $(BOARD_SUPER_PARTITION_SIZE)
endif

ifneq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),super)
INTERNAL_KERNEL_CMDLINE += androidboot.super_partition=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)
endif
BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE :=

endif # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS
endif # BOARD_SUPER_PARTITION_SIZE
.KATI_READONLY := BOARD_SUPER_PARTITION_BLOCK_DEVICES
.KATI_READONLY := BOARD_SUPER_PARTITION_METADATA_DEVICE
.KATI_READONLY := BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE

$(foreach device,$(call to-upper,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)), \
    $(eval BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE := $(strip $(BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE))) \
    $(if $(BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE),, \
        $(error BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE must not be empty)) \
    $(eval .KATI_READONLY := BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE))

endif # PRODUCT_BUILD_SUPER_PARTITION

# ###############################################################
# Set up final options.
# ###############################################################

# We run gcc/clang with PWD=/proc/self/cwd to remove the $TOP
# from the debug output. That way two builds in two different
# directories will create the same output.
# /proc doesn't exist on Darwin.
ifeq ($(HOST_OS),linux)
RELATIVE_PWD := PWD=/proc/self/cwd
else
RELATIVE_PWD :=
endif

TARGET_PROJECT_INCLUDES :=
TARGET_PROJECT_SYSTEM_INCLUDES := \
		$(TARGET_DEVICE_KERNEL_HEADERS) $(TARGET_BOARD_KERNEL_HEADERS) \
		$(TARGET_PRODUCT_KERNEL_HEADERS)

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_INCLUDES := $(TARGET_PROJECT_INCLUDES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_SYSTEM_INCLUDES := $(TARGET_PROJECT_SYSTEM_INCLUDES)
endif

# Flags for DEX2OAT
first_non_empty_of_three = $(if $(1),$(1),$(if $(2),$(2),$(3)))
DEX2OAT_TARGET_ARCH := $(TARGET_ARCH)
DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_CPU_VARIANT),$(TARGET_ARCH_VARIANT),default)
DEX2OAT_TARGET_CPU_VARIANT_RUNTIME := $(call first_non_empty_of_three,$(TARGET_CPU_VARIANT_RUNTIME),$(TARGET_ARCH_VARIANT),default)
DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH := $(TARGET_2ND_ARCH)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_2ND_CPU_VARIANT),$(TARGET_2ND_ARCH_VARIANT),default)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT_RUNTIME := $(call first_non_empty_of_three,$(TARGET_2ND_CPU_VARIANT_RUNTIME),$(TARGET_2ND_ARCH_VARIANT),default)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default
endif

# ###############################################################
# Collect a list of the SDK versions that we could compile against
# For use with the LOCAL_SDK_VERSION variable for include $(BUILD_PACKAGE)
# ###############################################################

HISTORICAL_SDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/sdk
HISTORICAL_NDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/ndk

# The path where app can reference the support library resources.
ifdef TARGET_BUILD_APPS
SUPPORT_LIBRARY_ROOT := $(HISTORICAL_SDK_VERSIONS_ROOT)/current/support
else
SUPPORT_LIBRARY_ROOT := frameworks/support
endif

get-sdk-version = $(if $(findstring _,$(1)),$(subst core_,,$(subst system_,,$(subst test_,,$(1)))),$(1))
get-sdk-api = $(if $(findstring _,$(1)),$(patsubst %_$(call get-sdk-version,$(1)),%,$(1)),public)
get-prebuilt-sdk-dir = $(HISTORICAL_SDK_VERSIONS_ROOT)/$(call get-sdk-version,$(1))/$(call get-sdk-api,$(1))

# Resolve LOCAL_SDK_VERSION to prebuilt module name, e.g.:
# 23 -> sdk_public_23_android
# system_current -> sdk_system_current_android
# $(1): An sdk version (LOCAL_SDK_VERSION)
# $(2): optional library name (default: android)
define resolve-prebuilt-sdk-module
$(if $(findstring _,$(1)),\
  sdk_$(1)_$(or $(2),android),\
  sdk_public_$(1)_$(or $(2),android))
endef

# Resolve LOCAL_SDK_VERSION to prebuilt android.jar
# $(1): LOCAL_SDK_VERSION
resolve-prebuilt-sdk-jar-path = $(call get-prebuilt-sdk-dir,$(1))/android.jar

# Resolve LOCAL_SDK_VERSION to prebuilt framework.aidl
# $(1): An sdk version (LOCAL_SDK_VERSION)
resolve-prebuilt-sdk-aidl-path = $(call get-prebuilt-sdk-dir,$(call get-sdk-version,$(1)))/framework.aidl

# Historical SDK version N is stored in $(HISTORICAL_SDK_VERSIONS_ROOT)/N.
# The 'current' version is whatever this source tree is.
#
# sgrax     is the opposite of xargs.  It takes the list of args and puts them
#           on each line for sort to process.
# sort -g   is a numeric sort, so 1 2 3 10 instead of 1 10 2 3.

# Numerically sort a list of numbers
# $(1): the list of numbers to be sorted
define numerically_sort
$(shell function sgrax() { \
    while [ -n "$$1" ] ; do echo $$1 ; shift ; done \
    } ; \
    ( sgrax $(1) | sort -g ) )
endef

# This produces a list like "current/core current/public current/system 4/public"
TARGET_AVAILABLE_SDK_VERSIONS := $(wildcard $(HISTORICAL_SDK_VERSIONS_ROOT)/*/*/android.jar)
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst $(HISTORICAL_SDK_VERSIONS_ROOT)/%/android.jar,%,$(TARGET_AVAILABLE_SDK_VERSIONS))
# Strips and reorganizes the "public", "core" and "system" subdirs.
TARGET_AVAILABLE_SDK_VERSIONS := $(subst /public,,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst %/core,core_%,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst %/system,system_%,$(TARGET_AVAILABLE_SDK_VERSIONS))
# No prebuilt for test_current.
TARGET_AVAILABLE_SDK_VERSIONS += test_current
TARGET_AVAIALBLE_SDK_VERSIONS := $(call numerically_sort,$(TARGET_AVAILABLE_SDK_VERSIONS))

TARGET_SDK_VERSIONS_WITHOUT_JAVA_18_SUPPORT := $(call numbers_less_than,24,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_SDK_VERSIONS_WITHOUT_JAVA_19_SUPPORT := $(call numbers_less_than,27,$(TARGET_AVAILABLE_SDK_VERSIONS))

ifndef INTERNAL_PLATFORM_PRIVATE_API_FILE
INTERNAL_PLATFORM_PRIVATE_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/private.txt
endif
ifndef INTERNAL_PLATFORM_PRIVATE_DEX_API_FILE
INTERNAL_PLATFORM_PRIVATE_DEX_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/private-dex.txt
endif
ifndef INTERNAL_PLATFORM_SYSTEM_PRIVATE_API_FILE
INTERNAL_PLATFORM_SYSTEM_PRIVATE_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/system-private.txt
endif
ifndef INTERNAL_PLATFORM_SYSTEM_PRIVATE_DEX_API_FILE
INTERNAL_PLATFORM_SYSTEM_PRIVATE_DEX_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/system-private-dex.txt
endif

# Missing optional uses-libraries so that the platform doesn't create build rules that depend on
# them. See setup_one_odex.mk.
INTERNAL_PLATFORM_MISSING_USES_LIBRARIES := com.google.android.ble com.google.android.wearable

# This is the standard way to name a directory containing prebuilt target
# objects. E.g., prebuilt/$(TARGET_PREBUILT_TAG)/libc.so
TARGET_PREBUILT_TAG := android-$(TARGET_ARCH)
ifdef TARGET_2ND_ARCH
TARGET_2ND_PREBUILT_TAG := android-$(TARGET_2ND_ARCH)
endif

# Set up RS prebuilt variables for compatibility library

RS_PREBUILT_CLCORE := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/librsrt_$(TARGET_ARCH).bc
RS_PREBUILT_COMPILER_RT := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/libcompiler_rt.a

# API Level lists for Renderscript Compat lib.
RSCOMPAT_32BIT_ONLY_API_LEVELS := 8 9 10 11 12 13 14 15 16 17 18 19 20
RSCOMPAT_NO_USAGEIO_API_LEVELS := 8 9 10 11 12 13

# Add BUILD_NUMBER to apps default version name if it's unbundled build.
ifdef TARGET_BUILD_APPS
TARGET_BUILD_WITH_APPS_VERSION_NAME := true
endif

ifdef TARGET_BUILD_WITH_APPS_VERSION_NAME
APPS_DEFAULT_VERSION_NAME := $(PLATFORM_VERSION)-$(BUILD_NUMBER_FROM_FILE)
else
APPS_DEFAULT_VERSION_NAME := $(PLATFORM_VERSION)
endif

# ANDROID_WARNING_ALLOWED_PROJECTS is generated by build/soong.
define find_warning_allowed_projects
    $(filter $(ANDROID_WARNING_ALLOWED_PROJECTS),$(1)/)
endef

# These goals don't need to collect and include Android.mks/CleanSpec.mks
# in the source tree.
dont_bother_goals := out \
    snod systemimage-nodeps \
    stnod systemtarball-nodeps \
    userdataimage-nodeps userdatatarball-nodeps \
    cacheimage-nodeps \
    bptimage-nodeps \
    vnod vendorimage-nodeps \
    pnod productimage-nodeps \
    psnod productservicesimage-nodeps \
    onod odmimage-nodeps \
    systemotherimage-nodeps \
    ramdisk-nodeps \
    ramdisk_debug-nodeps \
    bootimage-nodeps \
    bootimage_debug-nodeps \
    recoveryimage-nodeps \
    vbmetaimage-nodeps \
    product-graph dump-products

ifeq ($(CALLED_FROM_SETUP),true)
include $(BUILD_SYSTEM)/ninja_config.mk
include $(BUILD_SYSTEM)/soong_config.mk
endif

-include external/linux-kselftest/android/kselftest_test_list.mk
-include external/ltp/android/ltp_package_list.mk
DEFAULT_DATA_OUT_MODULES := ltp $(ltp_packages) $(kselftest_modules)
.KATI_READONLY := DEFAULT_DATA_OUT_MODULES

include $(BUILD_SYSTEM)/dumpvar.mk
