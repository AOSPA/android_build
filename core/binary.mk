###########################################################
## Standard rules for building binary object files from
## asm/c/cpp/yacc/lex/etc source files.
##
## The list of object files is exported in $(all_objects).
###########################################################

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
include $(BUILD_SYSTEM)/use_lld_setup.mk
#######################################

##################################################
# Compute the dependency of the shared libraries
##################################################
# On the target, we compile with -nostdlib, so we must add in the
# default system shared libraries, unless they have requested not
# to by supplying a LOCAL_SYSTEM_SHARED_LIBRARIES value.  One would
# supply that, for example, when building libc itself.
ifdef LOCAL_IS_HOST_MODULE
  ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
      my_system_shared_libraries :=
  else
      my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
  endif
else
  ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
      my_system_shared_libraries := libc libm libdl
  else
      my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
      my_system_shared_libraries := $(patsubst libc,libc libdl,$(my_system_shared_libraries))
  endif
endif

my_soong_problems :=

# The following LOCAL_ variables will be modified in this file.
# Because the same LOCAL_ variables may be used to define modules for both 1st arch and 2nd arch,
# we can't modify them in place.
my_src_files := $(LOCAL_SRC_FILES)
my_src_files_exclude := $(LOCAL_SRC_FILES_EXCLUDE)
my_static_libraries := $(LOCAL_STATIC_LIBRARIES)
my_whole_static_libraries := $(LOCAL_WHOLE_STATIC_LIBRARIES)
my_shared_libraries := $(filter-out $(my_system_shared_libraries),$(LOCAL_SHARED_LIBRARIES))
my_header_libraries := $(LOCAL_HEADER_LIBRARIES)
my_cflags := $(LOCAL_CFLAGS)
my_conlyflags := $(LOCAL_CONLYFLAGS)
my_cppflags := $(LOCAL_CPPFLAGS)
my_cflags_no_override := $(GLOBAL_CLANG_CFLAGS_NO_OVERRIDE)
my_cppflags_no_override := $(GLOBAL_CLANG_CPPFLAGS_NO_OVERRIDE)
my_ldflags := $(LOCAL_LDFLAGS)
my_ldlibs := $(LOCAL_LDLIBS)
my_asflags := $(LOCAL_ASFLAGS)
my_cc := $(LOCAL_CC)
my_cc_wrapper := $(CC_WRAPPER)
my_cxx := $(LOCAL_CXX)
my_cxx_ldlibs :=
my_cxx_wrapper := $(CXX_WRAPPER)
my_c_includes := $(LOCAL_C_INCLUDES)
my_generated_sources := $(LOCAL_GENERATED_SOURCES)
my_additional_dependencies := $(LOCAL_ADDITIONAL_DEPENDENCIES)
my_export_c_include_dirs := $(LOCAL_EXPORT_C_INCLUDE_DIRS)
my_export_c_include_deps := $(LOCAL_EXPORT_C_INCLUDE_DEPS)
my_arflags :=

ifneq (,$(strip $(foreach dir,$(COVERAGE_PATHS),$(filter $(dir)%,$(LOCAL_PATH)))))
ifeq (,$(strip $(foreach dir,$(COVERAGE_EXCLUDE_PATHS),$(filter $(dir)%,$(LOCAL_PATH)))))
  my_native_coverage := true
else
  my_native_coverage := false
endif
else
  my_native_coverage := false
endif
ifneq ($(NATIVE_COVERAGE),true)
  my_native_coverage := false
endif

ifneq ($(strip $(ENABLE_XOM)),false)
  ifndef LOCAL_IS_HOST_MODULE
    my_xom := true
    # Disable XOM in excluded paths.
    combined_xom_exclude_paths := $(XOM_EXCLUDE_PATHS) \
                                  $(PRODUCT_XOM_EXCLUDE_PATHS)
    ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_xom_exclude_paths)),\
           $(filter $(dir)%,$(LOCAL_PATH)))),)
      my_xom := false
    endif

    # Allow LOCAL_XOM to override the above
    ifdef LOCAL_XOM
      my_xom := $(LOCAL_XOM)
    endif

    ifeq ($(strip $(my_xom)),true)
      ifeq (arm64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
        ifeq ($(my_use_clang_lld),true)
          my_ldflags += -Wl,-execute-only
        endif
      endif
    endif
  endif
endif

my_allow_undefined_symbols := $(strip $(LOCAL_ALLOW_UNDEFINED_SYMBOLS))
ifdef SANITIZE_HOST
ifdef LOCAL_IS_HOST_MODULE
my_allow_undefined_symbols := true
endif
endif

my_ndk_sysroot :=
my_ndk_sysroot_include :=
my_ndk_sysroot_lib :=
ifneq ($(LOCAL_SDK_VERSION),)
  ifdef LOCAL_IS_HOST_MODULE
    $(error $(LOCAL_PATH): LOCAL_SDK_VERSION cannot be used in host module)
  endif

  # Make sure we've built the NDK.
  my_additional_dependencies += $(SOONG_OUT_DIR)/ndk_base.timestamp

  # mips32r6 is not supported by the NDK. No released NDK contains these
  # libraries, but the r10 in prebuilts/ndk had a local hack to add them :(
  #
  # We need to find a real solution to this problem, but until we do just drop
  # mips32r6 things back to r10 to get the tree building again.
  ifeq (mips32r6,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH_VARIANT))
    ifeq ($(LOCAL_NDK_VERSION), current)
      LOCAL_NDK_VERSION := r10
    endif
  endif

  my_arch := $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
  ifneq (,$(filter arm64 mips64 x86_64,$(my_arch)))
    my_min_sdk_version := 21
  else
    my_min_sdk_version := $(MIN_SUPPORTED_SDK_VERSION)
  endif

  # Historically we've just set up a bunch of symlinks in prebuilts/ndk to map
  # missing API levels to existing ones where necessary, but we're not doing
  # that for the generated libraries. Clip the API level to the minimum where
  # appropriate.
  my_ndk_api := $(LOCAL_SDK_VERSION)
  ifneq ($(my_ndk_api),current)
    my_ndk_api := $(call math_max,$(my_ndk_api),$(my_min_sdk_version))
  endif

  my_ndk_api_def := $(my_ndk_api)
  my_ndk_hist_api := $(my_ndk_api)
  ifeq ($(my_ndk_api),current)
    my_ndk_api_def := __ANDROID_API_FUTURE__
    # The last API level supported by the old prebuilt NDKs.
    my_ndk_hist_api := 24
  endif


  # Traditionally this has come from android/api-level.h, but with the libc
  # headers unified it must be set by the build system since we don't have
  # per-API level copies of that header now.
  my_cflags += -D__ANDROID_API__=$(my_ndk_api_def)

  my_ndk_source_root := \
      $(HISTORICAL_NDK_VERSIONS_ROOT)/$(LOCAL_NDK_VERSION)/sources
  my_ndk_sysroot := \
    $(HISTORICAL_NDK_VERSIONS_ROOT)/$(LOCAL_NDK_VERSION)/platforms/android-$(my_ndk_hist_api)/arch-$(my_arch)
  my_built_ndk := $(SOONG_OUT_DIR)/ndk
  my_ndk_triple := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_NDK_TRIPLE)
  my_ndk_sysroot_include := \
      $(my_built_ndk)/sysroot/usr/include \
      $(my_built_ndk)/sysroot/usr/include/$(my_ndk_triple) \
      $(my_ndk_sysroot)/usr/include \

  # x86_64 and and mips64 are both multilib toolchains, so their libraries are
  # installed in /usr/lib64. Aarch64, on the other hand, is not a multilib
  # compiler, so its libraries are in /usr/lib.
  #
  # Mips32r6 is yet another variation, with libraries installed in libr6.
  #
  # For the rest, the libraries are installed simply to /usr/lib.
  ifneq (,$(filter x86_64 mips64,$(my_arch)))
    my_ndk_libdir_name := lib64
  else ifeq (mips32r6,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH_VARIANT))
    my_ndk_libdir_name := libr6
  else
    my_ndk_libdir_name := lib
  endif

  my_ndk_platform_dir := \
      $(my_built_ndk)/platforms/android-$(my_ndk_api)/arch-$(my_arch)
  my_built_ndk_libs := $(my_ndk_platform_dir)/usr/$(my_ndk_libdir_name)
  my_ndk_sysroot_lib := $(my_ndk_sysroot)/usr/$(my_ndk_libdir_name)

  # The bionic linker now has support for packed relocations and gnu style
  # hashes (which are much faster!), but shipping to older devices requires
  # the old style hash. Fortunately, we can build with both and it'll work
  # anywhere.
  #
  # This is not currently supported on MIPS architectures.
  ifeq (,$(filter mips mips64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))
    my_ldflags += -Wl,--hash-style=both
  endif

  # We don't want to expose the relocation packer to the NDK just yet.
  LOCAL_PACK_MODULE_RELOCATIONS := false

  # Set up the NDK stl variant. Starting from NDK-r5 the c++ stl resides in a separate location.
  # See ndk/docs/CPLUSPLUS-SUPPORT.html
  my_ndk_stl_include_path :=
  my_ndk_stl_shared_lib_fullpath :=
  my_ndk_stl_static_lib :=
  my_cpu_variant := $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)CPU_ABI)
  ifeq (mips32r6,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH_VARIANT))
    my_cpu_variant := mips32r6
  endif
  LOCAL_NDK_STL_VARIANT := $(strip $(LOCAL_NDK_STL_VARIANT))
  ifeq (,$(LOCAL_NDK_STL_VARIANT))
    LOCAL_NDK_STL_VARIANT := system
  endif
  ifneq (1,$(words $(filter none system c++_static c++_shared, $(LOCAL_NDK_STL_VARIANT))))
    $(error $(LOCAL_PATH): Unknown LOCAL_NDK_STL_VARIANT $(LOCAL_NDK_STL_VARIANT))
  endif

  ifeq (system,$(LOCAL_NDK_STL_VARIANT))
    my_ndk_stl_include_path := $(my_ndk_source_root)/cxx-stl/system/include
    my_system_shared_libraries += libstdc++
  else ifneq (,$(filter c++_%, $(LOCAL_NDK_STL_VARIANT)))
    my_ndk_stl_include_path := \
      $(my_ndk_source_root)/cxx-stl/llvm-libc++/include
    my_ndk_stl_include_path += \
      $(my_ndk_source_root)/cxx-stl/llvm-libc++abi/include

    my_libcxx_libdir := \
      $(my_ndk_source_root)/cxx-stl/llvm-libc++/libs/$(my_cpu_variant)

    ifeq (c++_static,$(LOCAL_NDK_STL_VARIANT))
      my_ndk_stl_static_lib := \
        $(my_libcxx_libdir)/libc++_static.a \
        $(my_libcxx_libdir)/libc++abi.a
    else
      my_ndk_stl_shared_lib_fullpath := $(my_libcxx_libdir)/libc++_shared.so
    endif

    ifneq ($(my_ndk_api),current)
      ifeq ($(call math_lt,$(my_ndk_api),21),true)
        my_ndk_stl_include_path += $(my_ndk_source_root)/android/support/include
        my_ndk_stl_static_lib += $(my_libcxx_libdir)/libandroid_support.a
      endif
    endif

    ifneq (,$(filter armeabi armeabi-v7a,$(my_cpu_variant)))
      my_ndk_stl_static_lib += $(my_libcxx_libdir)/libunwind.a
    endif

    my_ldlibs += -ldl
  else # LOCAL_NDK_STL_VARIANT must be none
    # Do nothing.
  endif

  # Clang's coverage/profile runtime needs symbols like 'stderr' that were not
  # exported from libc prior to API level 23
  ifneq ($(my_ndk_api),current)
    ifeq ($(call math_lt, $(my_ndk_api),23),true)
      my_native_coverage := false
    endif
  endif
endif

ifneq ($(LOCAL_USE_VNDK),)
  # Required VNDK version for vendor modules is BOARD_VNDK_VERSION.
  my_vndk_version := $(BOARD_VNDK_VERSION)
  ifeq ($(my_vndk_version),current)
    # Build with current PLATFORM_VNDK_VERSION.
    # If PLATFORM_VNDK_VERSION has a CODENAME, it will return
    # __ANDROID_API_FUTURE__.
    my_vndk_version := $(call codename-or-sdk-to-sdk,$(PLATFORM_VNDK_VERSION))
  endif
  my_cflags += -D__ANDROID_API__=$(my_vndk_version) -D__ANDROID_VNDK__
endif

ifndef LOCAL_IS_HOST_MODULE
# For device libraries, move LOCAL_LDLIBS references to my_shared_libraries. We
# no longer need to use my_ldlibs to pick up NDK prebuilt libraries since we're
# linking my_shared_libraries by full path now.
my_allowed_ldlibs :=

# Sort ldlibs and ldflags between -l and other linker flags
# We'll do this again later, since there are still changes happening, but that's fine.
my_ldlib_flags := $(my_ldflags) $(my_ldlibs)
my_ldlibs := $(filter -l%,$(my_ldlib_flags))
my_ldflags := $(filter-out -l%,$(my_ldlib_flags))
my_ldlib_flags :=

# Move other ldlibs back to shared libraries
my_shared_libraries += $(patsubst -l%,lib%,$(filter-out $(my_allowed_ldlibs),$(my_ldlibs)))
my_ldlibs := $(filter $(my_allowed_ldlibs),$(my_ldlibs))
else # LOCAL_IS_HOST_MODULE
  # Add -ldl, -lpthread, -lm and -lrt to host builds to match the default behavior of
  # device builds
  my_ldlibs += -ldl -lpthread -lm
  ifneq ($(HOST_OS),darwin)
    my_ldlibs += -lrt
  endif
endif

ifneq ($(LOCAL_SDK_VERSION),)
  my_all_ndk_libraries := \
      $(NDK_MIGRATED_LIBS) $(addprefix lib,$(NDK_PREBUILT_SHARED_LIBRARIES))
  my_ndk_shared_libraries := \
      $(filter $(my_all_ndk_libraries),\
        $(my_shared_libraries) $(my_system_shared_libraries))

  my_shared_libraries := \
      $(filter-out $(my_all_ndk_libraries),$(my_shared_libraries))
  my_system_shared_libraries := \
      $(filter-out $(my_all_ndk_libraries),$(my_system_shared_libraries))
endif

# MinGW spits out warnings about -fPIC even for -fpie?!) being ignored because
# all code is position independent, and then those warnings get promoted to
# errors.
ifneq ($(LOCAL_NO_PIC),true)
  ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    my_cflags += -fPIE
    ifndef BUILD_HOST_static
      ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
        my_ldflags += -pie
      endif
    endif
  else
    my_cflags += -fPIC
  endif
endif

ifdef LOCAL_IS_HOST_MODULE
my_src_files += $(LOCAL_SRC_FILES_$($(my_prefix)OS)) $(LOCAL_SRC_FILES_$($(my_prefix)OS)_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
my_static_libraries += $(LOCAL_STATIC_LIBRARIES_$($(my_prefix)OS))
my_shared_libraries += $(LOCAL_SHARED_LIBRARIES_$($(my_prefix)OS))
my_header_libraries += $(LOCAL_HEADER_LIBRARIES_$($(my_prefix)OS))
my_cflags += $(LOCAL_CFLAGS_$($(my_prefix)OS))
my_cppflags += $(LOCAL_CPPFLAGS_$($(my_prefix)OS))
my_ldflags += $(LOCAL_LDFLAGS_$($(my_prefix)OS))
my_ldlibs += $(LOCAL_LDLIBS_$($(my_prefix)OS))
my_asflags += $(LOCAL_ASFLAGS_$($(my_prefix)OS))
my_c_includes += $(LOCAL_C_INCLUDES_$($(my_prefix)OS))
my_generated_sources += $(LOCAL_GENERATED_SOURCES_$($(my_prefix)OS))
endif

my_src_files += $(LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_SRC_FILES_$(my_32_64_bit_suffix))
my_src_files_exclude += $(LOCAL_SRC_FILES_EXCLUDE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_SRC_FILES_EXCLUDE_$(my_32_64_bit_suffix))
my_shared_libraries += $(LOCAL_SHARED_LIBRARIES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_SHARED_LIBRARIES_$(my_32_64_bit_suffix))
my_cflags += $(LOCAL_CFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CFLAGS_$(my_32_64_bit_suffix))
my_cppflags += $(LOCAL_CPPFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CPPFLAGS_$(my_32_64_bit_suffix))
my_ldflags += $(LOCAL_LDFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_LDFLAGS_$(my_32_64_bit_suffix))
my_asflags += $(LOCAL_ASFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_ASFLAGS_$(my_32_64_bit_suffix))
my_c_includes += $(LOCAL_C_INCLUDES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_C_INCLUDES_$(my_32_64_bit_suffix))
my_generated_sources += $(LOCAL_GENERATED_SOURCES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_GENERATED_SOURCES_$(my_32_64_bit_suffix))

my_missing_exclude_files := $(filter-out $(my_src_files),$(my_src_files_exclude))
ifneq ($(my_missing_exclude_files),)
$(warning Files are listed in LOCAL_SRC_FILES_EXCLUDE but not LOCAL_SRC_FILES)
$(error $(my_missing_exclude_files))
endif
my_src_files := $(filter-out $(my_src_files_exclude),$(my_src_files))

# Strip '/' from the beginning of each src file. This helps the ../ detection in case
# the source file is in the form of /../file
my_src_files := $(patsubst /%,%,$(my_src_files))

my_clang := $(strip $(LOCAL_CLANG))
ifdef LOCAL_CLANG_$(my_32_64_bit_suffix)
my_clang := $(strip $(LOCAL_CLANG_$(my_32_64_bit_suffix)))
endif
ifdef LOCAL_CLANG_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
my_clang := $(strip $(LOCAL_CLANG_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))
endif
ifeq ($(my_clang),false)
    $(call pretty-error,LOCAL_CLANG false is no longer supported)
endif

ifeq ($(LOCAL_C_STD),)
    my_c_std_version := $(DEFAULT_C_STD_VERSION)
else ifeq ($(LOCAL_C_STD),experimental)
    my_c_std_version := $(EXPERIMENTAL_C_STD_VERSION)
else
    my_c_std_version := $(LOCAL_C_STD)
endif

ifeq ($(LOCAL_CPP_STD),)
    my_cpp_std_version := $(DEFAULT_CPP_STD_VERSION)
else ifeq ($(LOCAL_CPP_STD),experimental)
    my_cpp_std_version := $(EXPERIMENTAL_CPP_STD_VERSION)
else
    my_cpp_std_version := $(LOCAL_CPP_STD)
endif

my_c_std_conlyflags :=
my_cpp_std_cppflags :=
ifneq (,$(my_c_std_version))
    my_c_std_conlyflags := -std=$(my_c_std_version)
endif

ifneq (,$(my_cpp_std_version))
   my_cpp_std_cppflags := -std=$(my_cpp_std_version)
endif

# Extra cflags for projects under external/ directory
ifneq ($(filter external/%,$(LOCAL_PATH)),)
    my_cflags += $(CLANG_EXTERNAL_CFLAGS)
endif

# arch-specific static libraries go first so that generic ones can depend on them
my_static_libraries := $(LOCAL_STATIC_LIBRARIES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_STATIC_LIBRARIES_$(my_32_64_bit_suffix)) $(my_static_libraries)
my_whole_static_libraries := $(LOCAL_WHOLE_STATIC_LIBRARIES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_WHOLE_STATIC_LIBRARIES_$(my_32_64_bit_suffix)) $(my_whole_static_libraries)
my_header_libraries := $(LOCAL_HEADER_LIBRARIES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_HEADER_LIBRARIES_$(my_32_64_bit_suffix)) $(my_header_libraries)

include $(BUILD_SYSTEM)/cxx_stl_setup.mk

# Add static HAL libraries
ifdef LOCAL_HAL_STATIC_LIBRARIES
$(foreach lib, $(LOCAL_HAL_STATIC_LIBRARIES), \
    $(eval b_lib := $(filter $(lib).%,$(BOARD_HAL_STATIC_LIBRARIES)))\
    $(if $(b_lib), $(eval my_static_libraries += $(b_lib)),\
                   $(eval my_static_libraries += $(lib).default)))
b_lib :=
endif

ifneq ($(strip $(CUSTOM_$(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)LINKER)),)
  my_linker := $(CUSTOM_$(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)LINKER)
else
  my_linker := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LINKER)
endif

include $(BUILD_SYSTEM)/config_sanitizers.mk

ifneq ($(filter ../%,$(my_src_files)),)
my_soong_problems += dotdot_srcs
endif
ifneq ($(foreach i,$(my_c_includes),$(filter %/..,$(i))$(findstring /../,$(i))),)
my_soong_problems += dotdot_incs
endif

####################################################
## Add FDO flags if FDO is turned on and supported
## Please note that we will do option filtering during FDO build.
## i.e. Os->O2, remove -fno-early-inline and -finline-limit.
##################################################################
my_fdo_build :=
ifneq ($(filter true always, $(LOCAL_FDO_SUPPORT)),)
  ifeq ($(BUILD_FDO_INSTRUMENT),true)
    my_cflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_INSTRUMENT_CFLAGS)
    my_ldflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_INSTRUMENT_LDFLAGS)
    my_fdo_build := true
  else ifneq ($(filter true,$(BUILD_FDO_OPTIMIZE))$(filter always,$(LOCAL_FDO_SUPPORT)),)
    my_cflags += $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_FDO_OPTIMIZE_CFLAGS)
    my_fdo_build := true
  endif
  # Disable ccache (or other compiler wrapper) except gomacc, which
  # can handle -fprofile-use properly.
  my_cc_wrapper := $(filter $(GOMA_CC),$(my_cc_wrapper))
  my_cxx_wrapper := $(filter $(GOMA_CC),$(my_cxx_wrapper))
endif

###########################################################
## Explicitly declare assembly-only __ASSEMBLY__ macro for
## assembly source
###########################################################
my_asflags += -D__ASSEMBLY__

###########################################################
# TODO: support a mix of standard extensions so that this isn't necessary
LOCAL_CPP_EXTENSION := $(strip $(LOCAL_CPP_EXTENSION))
ifeq ($(LOCAL_CPP_EXTENSION),)
  LOCAL_CPP_EXTENSION := .cpp
endif

# Certain modules like libdl have to have symbols resolved at runtime and blow
# up if --no-undefined is passed to the linker.
ifeq ($(strip $(LOCAL_NO_DEFAULT_COMPILER_FLAGS)),)
  ifeq ($(my_allow_undefined_symbols),)
    ifneq ($(HOST_OS),darwin)
      my_ldflags += -Wl,--no-undefined
    endif
  else
    ifdef LOCAL_IS_HOST_MODULE
      ifeq ($(HOST_OS),darwin)
        # darwin defaults to treating undefined symbols as errors
        my_ldflags += -Wl,-undefined,dynamic_lookup
      endif
    endif
  endif
endif

ifeq (true,$(LOCAL_GROUP_STATIC_LIBRARIES))
$(LOCAL_BUILT_MODULE): PRIVATE_GROUP_STATIC_LIBRARIES := true
else
$(LOCAL_BUILT_MODULE): PRIVATE_GROUP_STATIC_LIBRARIES :=
endif

###########################################################
## Define arm-vs-thumb-mode flags.
###########################################################
LOCAL_ARM_MODE := $(strip $(LOCAL_ARM_MODE))
ifeq ($($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),arm)
normal_objects_mode := $(if $(LOCAL_ARM_MODE),$(LOCAL_ARM_MODE),thumb)

# Read the values from something like TARGET_arm_CFLAGS or
# TARGET_thumb_CFLAGS.  HOST_(arm|thumb)_CFLAGS values aren't
# actually used (although they are usually empty).
normal_objects_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)$(normal_objects_mode)_CFLAGS)

else
normal_objects_mode :=
normal_objects_cflags :=
endif

###########################################################
## Define per-module debugging flags.  Users can turn on
## debugging for a particular module by setting DEBUG_MODULE_ModuleName
## to a non-empty value in their environment or buildspec.mk,
## and setting HOST_/TARGET_CUSTOM_DEBUG_CFLAGS to the
## debug flags that they want to use.
###########################################################
ifdef DEBUG_MODULE_$(strip $(LOCAL_MODULE))
  debug_cflags := $($(my_prefix)CUSTOM_DEBUG_CFLAGS)
else
  debug_cflags :=
endif

####################################################
## Keep track of src -> obj mapping
####################################################

my_tracked_gen_files :=
my_tracked_src_files :=

###########################################################
## Stuff source generated from one-off tools
###########################################################
$(my_generated_sources): PRIVATE_MODULE := $(my_register_name)

my_gen_sources_copy := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(filter $(generated_sources_dir)/%,$(my_generated_sources)))

$(my_gen_sources_copy): $(intermediates)/% : $(generated_sources_dir)/%
	@echo "Copy: $@"
	$(copy-file-to-target)

my_generated_sources := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(my_generated_sources))

# Generated sources that will actually produce object files.
# Other files (like headers) are allowed in LOCAL_GENERATED_SOURCES,
# since other compiled sources may depend on them, and we set up
# the dependencies.
my_gen_src_files := $(filter %.c %$(LOCAL_CPP_EXTENSION) %.S %.s,$(my_generated_sources))

ALL_GENERATED_SOURCES += $(my_generated_sources)

####################################################
## Compile RenderScript with reflected C++
####################################################

renderscript_sources := $(filter %.rs %.fs,$(my_src_files))

ifneq (,$(renderscript_sources))
my_soong_problems += rs

renderscript_sources_fullpath := $(addprefix $(LOCAL_PATH)/, $(renderscript_sources))
RenderScript_file_stamp := $(intermediates)/RenderScriptCPP.stamp
renderscript_intermediate := $(intermediates)/renderscript

renderscript_target_api :=

ifneq (,$(LOCAL_RENDERSCRIPT_TARGET_API))
renderscript_target_api := $(LOCAL_RENDERSCRIPT_TARGET_API)
else
ifneq (,$(LOCAL_SDK_VERSION))
# Set target-api for LOCAL_SDK_VERSIONs other than current.
ifneq (,$(filter-out current system_current test_current, $(LOCAL_SDK_VERSION)))
renderscript_target_api := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
endif
endif  # LOCAL_SDK_VERSION is set
endif  # LOCAL_RENDERSCRIPT_TARGET_API is set


ifeq ($(LOCAL_RENDERSCRIPT_CC),)
LOCAL_RENDERSCRIPT_CC := $(LLVM_RS_CC)
endif

# Turn on all warnings and warnings as errors for RS compiles.
# This can be disabled with LOCAL_RENDERSCRIPT_FLAGS := -Wno-error
renderscript_flags := -Wall -Werror
renderscript_flags += $(LOCAL_RENDERSCRIPT_FLAGS)
# -m32 or -m64
renderscript_flags += -m$(my_32_64_bit_suffix)

renderscript_includes := \
    $(TOPDIR)external/clang/lib/Headers \
    $(TOPDIR)frameworks/rs/script_api/include \
    $(LOCAL_RENDERSCRIPT_INCLUDES)

ifneq ($(LOCAL_RENDERSCRIPT_INCLUDES_OVERRIDE),)
renderscript_includes := $(LOCAL_RENDERSCRIPT_INCLUDES_OVERRIDE)
endif

bc_dep_files := $(addprefix $(renderscript_intermediate)/, \
    $(patsubst %.fs,%.d, $(patsubst %.rs,%.d, $(notdir $(renderscript_sources)))))

$(RenderScript_file_stamp): PRIVATE_RS_INCLUDES := $(renderscript_includes)
$(RenderScript_file_stamp): PRIVATE_RS_CC := $(LOCAL_RENDERSCRIPT_CC)
$(RenderScript_file_stamp): PRIVATE_RS_FLAGS := $(renderscript_flags)
$(RenderScript_file_stamp): PRIVATE_RS_SOURCE_FILES := $(renderscript_sources_fullpath)
$(RenderScript_file_stamp): PRIVATE_RS_OUTPUT_DIR := $(renderscript_intermediate)
$(RenderScript_file_stamp): PRIVATE_RS_TARGET_API := $(patsubst current,0,$(renderscript_target_api))
$(RenderScript_file_stamp): PRIVATE_DEP_FILES := $(bc_dep_files)
$(RenderScript_file_stamp): $(renderscript_sources_fullpath) $(LOCAL_RENDERSCRIPT_CC)
	$(transform-renderscripts-to-cpp-and-bc)

# include the dependency files (.d) generated by llvm-rs-cc.
$(call include-depfile,$(RenderScript_file_stamp).d,$(RenderScript_file_stamp))

LOCAL_INTERMEDIATE_TARGETS += $(RenderScript_file_stamp)

rs_generated_cpps := $(addprefix \
    $(renderscript_intermediate)/ScriptC_,$(patsubst %.fs,%.cpp, $(patsubst %.rs,%.cpp, \
    $(notdir $(renderscript_sources)))))

$(call track-src-file-gen,$(renderscript_sources),$(rs_generated_cpps))

# This is just a dummy rule to make sure gmake doesn't skip updating the dependents.
$(rs_generated_cpps) : $(RenderScript_file_stamp)
	@echo "Updated RS generated cpp file $@."
	$(hide) touch $@

my_c_includes += $(renderscript_intermediate)
my_generated_sources += $(rs_generated_cpps)

endif


###########################################################
## Compile the .proto files to .cc (or .c) and then to .o
###########################################################
ifeq ($(strip $(LOCAL_PROTOC_OPTIMIZE_TYPE)),)
  LOCAL_PROTOC_OPTIMIZE_TYPE := lite
endif
proto_sources := $(filter %.proto,$(my_src_files))
ifneq ($(proto_sources),)
proto_gen_dir := $(generated_sources_dir)/proto
proto_sources_fullpath := $(addprefix $(LOCAL_PATH)/, $(proto_sources))

my_rename_cpp_ext :=
ifneq (,$(filter nanopb-c nanopb-c-enable_malloc nanopb-c-16bit nanopb-c-enable_malloc-16bit nanopb-c-32bit nanopb-c-enable_malloc-32bit, $(LOCAL_PROTOC_OPTIMIZE_TYPE)))
my_proto_source_suffix := .c
my_proto_c_includes := external/nanopb-c
my_protoc_flags := --nanopb_out=$(proto_gen_dir) \
    --plugin=$(HOST_OUT_EXECUTABLES)/protoc-gen-nanopb
my_protoc_deps := $(NANOPB_SRCS) $(proto_sources_fullpath:%.proto=%.options)
else
my_proto_source_suffix := $(LOCAL_CPP_EXTENSION)
ifneq ($(my_proto_source_suffix),.cc)
# aprotoc is hardcoded to write out only .cc file.
# We need to rename the extension to $(LOCAL_CPP_EXTENSION) if it's not .cc.
my_rename_cpp_ext := true
endif
my_proto_c_includes := external/protobuf/src
my_cflags += -DGOOGLE_PROTOBUF_NO_RTTI
my_protoc_flags := --cpp_out=$(if $(filter lite lite-static,$(LOCAL_PROTOC_OPTIMIZE_TYPE)),lite:,)$(proto_gen_dir)
my_protoc_deps :=
endif
my_proto_c_includes += $(proto_gen_dir)

proto_generated_cpps := $(addprefix $(proto_gen_dir)/, \
    $(patsubst %.proto,%.pb$(my_proto_source_suffix),$(proto_sources_fullpath)))

# Ensure the transform-proto-to-cc rule is only defined once in multilib build.
ifndef $(my_host)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_proto_defined
$(proto_generated_cpps): PRIVATE_PROTO_INCLUDES := $(TOP)
$(proto_generated_cpps): PRIVATE_PROTOC_FLAGS := $(LOCAL_PROTOC_FLAGS) $(my_protoc_flags)
$(proto_generated_cpps): PRIVATE_RENAME_CPP_EXT := $(my_rename_cpp_ext)
$(proto_generated_cpps): $(proto_gen_dir)/%.pb$(my_proto_source_suffix): %.proto $(my_protoc_deps) $(PROTOC)
	$(transform-proto-to-cc)

$(my_host)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_proto_defined := true
endif
# Ideally we can generate the source directly into $(intermediates).
# But many Android.mks assume the .pb.hs are in $(generated_sources_dir).
# As a workaround, we make a copy in the $(intermediates).
proto_intermediate_dir := $(intermediates)/proto
proto_intermediate_cpps := $(patsubst $(proto_gen_dir)/%,$(proto_intermediate_dir)/%,\
    $(proto_generated_cpps))
$(proto_intermediate_cpps) : $(proto_intermediate_dir)/% : $(proto_gen_dir)/%
	@echo "Copy: $@"
	$(copy-file-to-target)
	$(hide) cp $(basename $<).h $(basename $@).h
$(call track-src-file-gen,$(proto_sources),$(proto_intermediate_cpps))

my_generated_sources += $(proto_intermediate_cpps)

my_c_includes += $(my_proto_c_includes)
# Auto-export the generated proto source dir.
my_export_c_include_dirs += $(my_proto_c_includes)

ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c-enable_malloc)
    my_static_libraries += libprotobuf-c-nano-enable_malloc
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c)
    my_static_libraries += libprotobuf-c-nano
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c-enable_malloc-16bit)
    my_static_libraries += libprotobuf-c-nano-enable_malloc-16bit
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c-16bit)
    my_static_libraries += libprotobuf-c-nano-16bit
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c-enable_malloc-32bit)
    my_static_libraries += libprotobuf-c-nano-enable_malloc-32bit
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nanopb-c-32bit)
    my_static_libraries += libprotobuf-c-nano-32bit
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),full)
    ifdef LOCAL_SDK_VERSION
        my_static_libraries += libprotobuf-cpp-full-ndk
    else
        my_shared_libraries += libprotobuf-cpp-full
    endif
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),lite-static)
    my_static_libraries += libprotobuf-cpp-lite
else
    ifdef LOCAL_SDK_VERSION
        my_static_libraries += libprotobuf-cpp-lite-ndk
    else
        my_shared_libraries += libprotobuf-cpp-lite
    endif
endif
endif  # $(proto_sources) non-empty

###########################################################
## AIDL: Compile .aidl files to .cpp and .h files
###########################################################
aidl_src := $(strip $(filter %.aidl,$(my_src_files)))
aidl_gen_cpp :=
ifneq ($(aidl_src),)

# Use the intermediates directory to avoid writing our own .cpp -> .o rules.
aidl_gen_cpp_root := $(intermediates)/aidl-generated/src
aidl_gen_include_root := $(intermediates)/aidl-generated/include

# Multi-architecture builds have distinct intermediates directories.
# Thus we'll actually generate source for each architecture.
$(foreach s,$(aidl_src),\
    $(eval $(call define-aidl-cpp-rule,$(s),$(aidl_gen_cpp_root),aidl_gen_cpp)))
$(foreach cpp,$(aidl_gen_cpp), \
    $(call include-depfile,$(addsuffix .aidl.d,$(basename $(cpp))),$(cpp)))
$(call track-src-file-gen,$(aidl_src),$(aidl_gen_cpp))

$(aidl_gen_cpp) : PRIVATE_MODULE := $(LOCAL_MODULE)
$(aidl_gen_cpp) : PRIVATE_HEADER_OUTPUT_DIR := $(aidl_gen_include_root)
$(aidl_gen_cpp) : PRIVATE_AIDL_FLAGS := $(addprefix -I,$(LOCAL_AIDL_INCLUDES))

# Add generated headers to include paths.
my_c_includes += $(aidl_gen_include_root)
my_export_c_include_dirs += $(aidl_gen_include_root)
# Pick up the generated C++ files later for transformation to .o files.
my_generated_sources += $(aidl_gen_cpp)

endif  # $(aidl_src) non-empty

###########################################################
## Compile the .vts files to .cc (or .c) and then to .o
###########################################################

vts_src := $(strip $(filter %.vts,$(my_src_files)))
vts_gen_cpp :=
ifneq ($(vts_src),)
my_soong_problems += vts

# Use the intermediates directory to avoid writing our own .cpp -> .o rules.
vts_gen_cpp_root := $(intermediates)/vts-generated/src
vts_gen_include_root := $(intermediates)/vts-generated/include

# Multi-architecture builds have distinct intermediates directories.
# Thus we'll actually generate source for each architecture.
$(foreach s,$(vts_src),\
    $(eval $(call define-vts-cpp-rule,$(s),$(vts_gen_cpp_root),vts_gen_cpp)))
$(call track-src-file-gen,$(vts_src),$(vts_gen_cpp))

$(vts_gen_cpp) : PRIVATE_MODULE := $(LOCAL_MODULE)
$(vts_gen_cpp) : PRIVATE_HEADER_OUTPUT_DIR := $(vts_gen_include_root)
$(vts_gen_cpp) : PRIVATE_VTS_FLAGS := $(addprefix -I,$(LOCAL_VTS_INCLUDES)) $(addprefix -m,$(LOCAL_VTS_MODE))

# Add generated headers to include paths.
my_c_includes += $(vts_gen_include_root)
my_export_c_include_dirs += $(vts_gen_include_root)
# Pick up the generated C++ files later for transformation to .o files.
my_generated_sources += $(vts_gen_cpp)

endif  # $(vts_src) non-empty

###########################################################
## YACC: Compile .y/.yy files to .c/.cpp and then to .o.
###########################################################

y_yacc_sources := $(filter %.y,$(my_src_files))
y_yacc_cs := $(addprefix \
    $(intermediates)/,$(y_yacc_sources:.y=.c))
ifneq ($(y_yacc_cs),)
$(y_yacc_cs): $(intermediates)/%.c: \
    $(TOPDIR)$(LOCAL_PATH)/%.y $(BISON) $(BISON_DATA) \
    $(my_additional_dependencies)
	$(call transform-y-to-c-or-cpp)
$(call track-src-file-gen,$(y_yacc_sources),$(y_yacc_cs))

my_generated_sources += $(y_yacc_cs)
endif

yy_yacc_sources := $(filter %.yy,$(my_src_files))
yy_yacc_cpps := $(addprefix \
    $(intermediates)/,$(yy_yacc_sources:.yy=$(LOCAL_CPP_EXTENSION)))
ifneq ($(yy_yacc_cpps),)
$(yy_yacc_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.yy $(BISON) $(BISON_DATA) \
    $(my_additional_dependencies)
	$(call transform-y-to-c-or-cpp)
$(call track-src-file-gen,$(yy_yacc_sources),$(yy_yacc_cpps))

my_generated_sources += $(yy_yacc_cpps)
endif

###########################################################
## LEX: Compile .l/.ll files to .c/.cpp and then to .o.
###########################################################

l_lex_sources := $(filter %.l,$(my_src_files))
l_lex_cs := $(addprefix \
    $(intermediates)/,$(l_lex_sources:.l=.c))
ifneq ($(l_lex_cs),)
$(l_lex_cs): $(intermediates)/%.c: \
    $(TOPDIR)$(LOCAL_PATH)/%.l
	$(transform-l-to-c-or-cpp)
$(call track-src-file-gen,$(l_lex_sources),$(l_lex_cs))

my_generated_sources += $(l_lex_cs)
endif

ll_lex_sources := $(filter %.ll,$(my_src_files))
ll_lex_cpps := $(addprefix \
    $(intermediates)/,$(ll_lex_sources:.ll=$(LOCAL_CPP_EXTENSION)))
ifneq ($(ll_lex_cpps),)
$(ll_lex_cpps): $(intermediates)/%$(LOCAL_CPP_EXTENSION): \
    $(TOPDIR)$(LOCAL_PATH)/%.ll
	$(transform-l-to-c-or-cpp)
$(call track-src-file-gen,$(ll_lex_sources),$(ll_lex_cpps))

my_generated_sources += $(ll_lex_cpps)
endif

###########################################################
## C++: Compile .cpp files to .o.
###########################################################

ifneq ($(filter %$(LOCAL_CPP_EXTENSION).arm,$(my_src_files)),)
$(call pretty-error,Files ending in $(LOCAL_CPP_EXTENSION).arm are deprecated. See $(CHANGES_URL)#file_arm)
endif

dotdot_sources := $(filter ../%$(LOCAL_CPP_EXTENSION),$(my_src_files))
dotdot_objects :=
$(foreach s,$(dotdot_sources),\
  $(eval $(call compile-dotdot-cpp-file,$(s),\
    $(my_additional_dependencies),\
    dotdot_objects)))
$(call track-src-file-obj,$(dotdot_sources),$(dotdot_objects))

cpp_normal_sources := $(filter-out ../%,$(filter %$(LOCAL_CPP_EXTENSION),$(my_src_files)))
cpp_objects := $(addprefix $(intermediates)/,$(cpp_normal_sources:$(LOCAL_CPP_EXTENSION)=.o))
$(call track-src-file-obj,$(cpp_normal_sources),$(cpp_objects))

$(dotdot_objects) $(cpp_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(dotdot_objects) $(cpp_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

ifneq ($(strip $(cpp_objects)),)
$(cpp_objects): $(intermediates)/%.o: \
    $(TOPDIR)$(LOCAL_PATH)/%$(LOCAL_CPP_EXTENSION) \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
$(call include-depfiles-for-objs, $(cpp_objects))
endif

cpp_objects += $(dotdot_objects)

###########################################################
## C++: Compile generated .cpp files to .o.
###########################################################

gen_cpp_sources := $(filter %$(LOCAL_CPP_EXTENSION),$(my_generated_sources))
gen_cpp_objects := $(gen_cpp_sources:%$(LOCAL_CPP_EXTENSION)=%.o)
$(call track-gen-file-obj,$(gen_cpp_sources),$(gen_cpp_objects))

ifneq ($(strip $(gen_cpp_objects)),)
# Compile all generated files as thumb.
$(gen_cpp_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(gen_cpp_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(gen_cpp_objects): $(intermediates)/%.o: \
    $(intermediates)/%$(LOCAL_CPP_EXTENSION) \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)cpp-to-o)
$(call include-depfiles-for-objs, $(gen_cpp_objects))
endif

###########################################################
## S: Compile generated .S and .s files to .o.
###########################################################

gen_S_sources := $(filter %.S,$(my_generated_sources))
gen_S_objects := $(gen_S_sources:%.S=%.o)
$(call track-gen-file-obj,$(gen_S_sources),$(gen_S_objects))

ifneq ($(strip $(gen_S_sources)),)
$(gen_S_objects): $(intermediates)/%.o: $(intermediates)/%.S \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
$(call include-depfiles-for-objs, $(gen_S_objects))
endif

gen_s_sources := $(filter %.s,$(my_generated_sources))
gen_s_objects := $(gen_s_sources:%.s=%.o)
$(call track-gen-file-obj,$(gen_s_sources),$(gen_s_objects))

ifneq ($(strip $(gen_s_objects)),)
$(gen_s_objects): $(intermediates)/%.o: $(intermediates)/%.s \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
endif

gen_asm_objects := $(gen_S_objects) $(gen_s_objects)
$(gen_asm_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

###########################################################
## o: Include generated .o files in output.
###########################################################

gen_o_objects := $(filter %.o,$(my_generated_sources))

###########################################################
## C: Compile .c files to .o.
###########################################################

ifneq ($(filter %.c.arm,$(my_src_files)),)
$(call pretty-error,Files ending in .c.arm are deprecated. See $(CHANGES_URL)#file_arm)
endif

dotdot_sources := $(filter ../%.c, $(my_src_files))
dotdot_objects :=
$(foreach s, $(dotdot_sources),\
  $(eval $(call compile-dotdot-c-file,$(s),\
    $(my_additional_dependencies),\
    dotdot_objects)))
$(call track-src-file-obj,$(dotdot_sources),$(dotdot_objects))

c_normal_sources := $(filter-out ../%,$(filter %.c,$(my_src_files)))
c_objects := $(addprefix $(intermediates)/,$(c_normal_sources:.c=.o))
$(call track-src-file-obj,$(c_normal_sources),$(c_objects))

$(dotdot_objects) $(c_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(dotdot_objects) $(c_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)

ifneq ($(strip $(c_objects)),)
$(c_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.c \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)c-to-o)
$(call include-depfiles-for-objs, $(c_objects))
endif

c_objects += $(dotdot_objects)

###########################################################
## C: Compile generated .c files to .o.
###########################################################

gen_c_sources := $(filter %.c,$(my_generated_sources))
gen_c_objects := $(gen_c_sources:%.c=%.o)
$(call track-gen-file-obj,$(gen_c_sources),$(gen_c_objects))

ifneq ($(strip $(gen_c_objects)),)
# Compile all generated files as thumb.
$(gen_c_objects): PRIVATE_ARM_MODE := $(normal_objects_mode)
$(gen_c_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)
$(gen_c_objects): $(intermediates)/%.o: $(intermediates)/%.c \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)c-to-o)
$(call include-depfiles-for-objs, $(gen_c_objects))
endif

###########################################################
## ObjC: Compile .m files to .o
###########################################################

objc_sources := $(filter %.m,$(my_src_files))
objc_objects := $(addprefix $(intermediates)/,$(objc_sources:.m=.o))
$(call track-src-file-obj,$(objc_sources),$(objc_objects))

ifneq ($(strip $(objc_objects)),)
my_soong_problems += objc
$(objc_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.m \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)m-to-o)
$(call include-depfiles-for-objs, $(objc_objects))
endif

###########################################################
## ObjC++: Compile .mm files to .o
###########################################################

objcpp_sources := $(filter %.mm,$(my_src_files))
objcpp_objects := $(addprefix $(intermediates)/,$(objcpp_sources:.mm=.o))
$(call track-src-file-obj,$(objcpp_sources),$(objcpp_objects))

ifneq ($(strip $(objcpp_objects)),)
$(objcpp_objects): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.mm \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)mm-to-o)
$(call include-depfiles-for-objs, $(objcpp_objects))
endif

###########################################################
## AS: Compile .S files to .o.
###########################################################

asm_sources_S := $(filter %.S,$(my_src_files))
dotdot_sources := $(filter ../%,$(asm_sources_S))
asm_sources_S := $(filter-out ../%,$(asm_sources_S))
asm_objects_S := $(addprefix $(intermediates)/,$(asm_sources_S:.S=.o))
$(call track-src-file-obj,$(asm_sources_S),$(asm_objects_S))

dotdot_objects_S :=
$(foreach s,$(dotdot_sources),\
  $(eval $(call compile-dotdot-s-file,$(s),\
    $(my_additional_dependencies),\
    dotdot_objects_S)))
$(call track-src-file-obj,$(dotdot_sources),$(dotdot_objects_S))

ifneq ($(strip $(asm_objects_S)),)
$(asm_objects_S): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.S \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
$(call include-depfiles-for-objs, $(asm_objects_S))
endif

asm_sources_s := $(filter %.s,$(my_src_files))
dotdot_sources := $(filter ../%,$(asm_sources_s))
asm_sources_s := $(filter-out ../%,$(asm_sources_s))
asm_objects_s := $(addprefix $(intermediates)/,$(asm_sources_s:.s=.o))
$(call track-src-file-obj,$(asm_sources_s),$(asm_objects_s))

dotdot_objects_s :=
$(foreach s,$(dotdot_sources),\
  $(eval $(call compile-dotdot-s-file-no-deps,$(s),\
    $(my_additional_dependencies),\
    dotdot_objects_s)))
$(call track-src-file-obj,$(dotdot_sources),$(dotdot_objects_s))

ifneq ($(strip $(asm_objects_s)),)
$(asm_objects_s): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.s \
    $(my_additional_dependencies)
	$(transform-$(PRIVATE_HOST)s-to-o)
endif

asm_objects := $(dotdot_objects_S) $(dotdot_objects_s) $(asm_objects_S) $(asm_objects_s)
$(asm_objects): PRIVATE_ARM_CFLAGS := $(normal_objects_cflags)


# .asm for x86/x86_64 needs to be compiled with yasm.
asm_sources_asm := $(filter %.asm,$(my_src_files))
ifneq ($(strip $(asm_sources_asm)),)
asm_objects_asm := $(addprefix $(intermediates)/,$(asm_sources_asm:.asm=.o))
$(asm_objects_asm): $(intermediates)/%.o: $(TOPDIR)$(LOCAL_PATH)/%.asm \
    $(my_additional_dependencies)
	$(transform-asm-to-o)
$(call track-src-file-obj,$(asm_sources_asm),$(asm_objects_asm))

asm_objects += $(asm_objects_asm)
endif

###################################################################
## When compiling a CFI enabled target, use the .cfi variant of any
## static dependencies (where they exist).
##################################################################
define use_soong_cfi_static_libraries
  $(foreach l,$(1),$(if $(filter $(l),$(SOONG_CFI_STATIC_LIBRARIES)),\
      $(l).cfi,$(l)))
endef

ifneq ($(filter cfi,$(my_sanitize)),)
  my_whole_static_libraries := $(call use_soong_cfi_static_libraries,\
    $(my_whole_static_libraries))
  my_static_libraries := $(call use_soong_cfi_static_libraries,\
    $(my_static_libraries))
endif

ifneq ($(LOCAL_USE_VNDK),)
  my_soong_hwasan_static_libraries := $(SOONG_HWASAN_VENDOR_STATIC_LIBRARIES)
else
  my_soong_hwasan_static_libraries = $(SOONG_HWASAN_STATIC_LIBRARIES)
endif

define use_soong_hwasan_static_libraries
  $(foreach l,$(1),$(if $(filter $(l),$(my_soong_hwasan_static_libraries)),\
      $(l).hwasan,$(l)))
endef

ifneq ($(filter hwaddress,$(my_sanitize)),)
  my_whole_static_libraries := $(call use_soong_hwasan_static_libraries,\
    $(my_whole_static_libraries))
  my_static_libraries := $(call use_soong_hwasan_static_libraries,\
    $(my_static_libraries))
endif

###########################################################
## When compiling against the VNDK, use LL-NDK libraries
###########################################################
ifneq ($(LOCAL_USE_VNDK),)
  ####################################################
  ## Soong modules may be built twice, once for /system
  ## and once for /vendor. If we're using the VNDK,
  ## switch all soong libraries over to the /vendor
  ## variant.
  ####################################################
  my_whole_static_libraries := $(foreach l,$(my_whole_static_libraries),\
    $(if $(SPLIT_VENDOR.STATIC_LIBRARIES.$(l)),$(l).vendor,$(l)))
  my_static_libraries := $(foreach l,$(my_static_libraries),\
    $(if $(SPLIT_VENDOR.STATIC_LIBRARIES.$(l)),$(l).vendor,$(l)))
  my_shared_libraries := $(foreach l,$(my_shared_libraries),\
    $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
  my_system_shared_libraries := $(foreach l,$(my_system_shared_libraries),\
    $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
  my_header_libraries := $(foreach l,$(my_header_libraries),\
    $(if $(SPLIT_VENDOR.HEADER_LIBRARIES.$(l)),$(l).vendor,$(l)))
endif

# Platform can use vendor public libraries. If a required shared lib is one of
# the vendor public libraries, the lib is switched to the stub version of the lib.
ifeq ($(LOCAL_USE_VNDK),)
  my_shared_libraries := $(foreach l,$(my_shared_libraries),\
    $(if $(filter $(l),$(VENDOR_PUBLIC_LIBRARIES)),$(l).vendorpublic,$(l)))
endif

##########################################################
## Set up installed module dependency
## We cannot compute the full path of the LOCAL_SHARED_LIBRARIES for
## they may cusomize their install path with LOCAL_MODULE_PATH
##########################################################
# Get the list of INSTALLED libraries as module names.
ifneq ($(LOCAL_SDK_VERSION),)
  installed_shared_library_module_names := \
      $(my_shared_libraries)
else
  installed_shared_library_module_names := \
      $(my_shared_libraries) $(my_system_shared_libraries)
endif

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef installed_shared_library_module_names
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
    $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(installed_shared_library_module_names))
endif
endif


####################################################
## Import includes
####################################################
import_includes := $(intermediates)/import_includes
import_includes_deps := $(strip \
    $(if $(LOCAL_USE_VNDK),\
      $(call intermediates-dir-for,HEADER_LIBRARIES,device_kernel_headers,$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes) \
    $(foreach l, $(installed_shared_library_module_names), \
      $(call intermediates-dir-for,SHARED_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes) \
    $(foreach l, $(my_static_libraries) $(my_whole_static_libraries), \
      $(call intermediates-dir-for,STATIC_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes) \
    $(foreach l, $(my_header_libraries), \
      $(call intermediates-dir-for,HEADER_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes))
$(import_includes): PRIVATE_IMPORT_EXPORT_INCLUDES := $(import_includes_deps)
$(import_includes) : $(import_includes_deps)
	@echo Import includes file: $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef import_includes_deps
	$(hide) for f in $(PRIVATE_IMPORT_EXPORT_INCLUDES); do \
	  cat $$f >> $@; \
	done
else
	$(hide) touch $@
endif

####################################################
## Verify that NDK-built libraries only link against
## other NDK-built libraries
####################################################

include $(BUILD_SYSTEM)/allowed_ndk_types.mk

ifdef LOCAL_SDK_VERSION
my_link_type := native:ndk:$(my_ndk_stl_family):$(my_ndk_stl_link_type)
my_warn_types := $(my_warn_ndk_types)
my_allowed_types := $(my_allowed_ndk_types)
else ifdef LOCAL_USE_VNDK
    _name := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(filter $(_name),$(VNDK_CORE_LIBRARIES) $(VNDK_SAMEPROCESS_LIBRARIES) $(LLNDK_LIBRARIES)),)
        ifeq ($(filter $(_name),$(VNDK_PRIVATE_LIBRARIES)),)
            my_link_type := native:vndk
        else
            my_link_type := native:vndk_private
        endif
        my_warn_types :=
        my_allowed_types := native:vndk native:vndk_private
    else
        # Modules installed to /vendor cannot directly depend on modules marked
        # with vendor_available: false
        my_link_type := native:vendor
        my_warn_types :=
        my_allowed_types := native:vendor native:vndk native:platform_vndk
    endif
else ifneq ($(filter $(TARGET_RECOVERY_OUT)/%,$(call get_non_asan_path,$(LOCAL_MODULE_PATH))),)
my_link_type := native:recovery
my_warn_types :=
# TODO(b/113303515) remove native:platform and my_allowed_ndk_types
my_allowed_types := native:recovery native:platform native:platform_vndk $(my_allowed_ndk_types)
else
my_link_type := native:platform
my_warn_types := $(my_warn_ndk_types)
my_allowed_types := $(my_allowed_ndk_types) native:platform native:platform_vndk
endif

my_link_deps := $(addprefix STATIC_LIBRARIES:,$(my_whole_static_libraries) $(my_static_libraries))
ifneq ($(filter-out STATIC_LIBRARIES HEADER_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
my_link_deps += $(addprefix SHARED_LIBRARIES:,$(my_shared_libraries))
endif

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common :=
include $(BUILD_SYSTEM)/link_type.mk

###########################################################
## Common object handling.
###########################################################

my_unused_src_files := $(filter-out $(logtags_sources) $(my_tracked_src_files),$(my_src_files) $(my_gen_src_files))
ifneq ($(my_unused_src_files),)
  $(error $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Unused source files: $(my_unused_src_files))
endif

# some rules depend on asm_objects being first.  If your code depends on
# being first, it's reasonable to require it to be assembly
normal_objects := \
    $(asm_objects) \
    $(cpp_objects) \
    $(gen_cpp_objects) \
    $(gen_asm_objects) \
    $(c_objects) \
    $(gen_c_objects) \
    $(objc_objects) \
    $(objcpp_objects)

new_order_normal_objects := $(foreach f,$(my_src_files),$(my_src_file_obj_$(f)))
new_order_normal_objects += $(foreach f,$(my_gen_src_files),$(my_src_file_obj_$(f)))

ifneq ($(sort $(normal_objects)),$(sort $(new_order_normal_objects)))
$(warning $(LOCAL_MODULE_MAKEFILE) Internal build system warning: New object list does not match old)
$(info Only in old: $(filter-out $(new_order_normal_objects),$(sort $(normal_objects))))
$(info Only in new: $(filter-out $(normal_objects),$(sort $(new_order_normal_objects))))
endif

ifeq ($(BINARY_OBJECTS_ORDER),soong)
normal_objects := $(new_order_normal_objects)
endif

normal_objects += $(addprefix $(TOPDIR)$(LOCAL_PATH)/,$(LOCAL_PREBUILT_OBJ_FILES))

all_objects := $(normal_objects) $(gen_o_objects)

LOCAL_INTERMEDIATE_TARGETS += $(all_objects)

# Cleanup file tracking
$(foreach f,$(my_tracked_gen_files),$(eval my_src_file_gen_$(s):=))
my_tracked_gen_files :=
$(foreach f,$(my_tracked_src_files),$(eval my_src_file_obj_$(s):=))
my_tracked_src_files :=

my_c_includes += $(TOPDIR)$(LOCAL_PATH) $(intermediates) $(generated_sources_dir)

# The platform JNI header is for platform modules only.
ifeq ($(LOCAL_SDK_VERSION)$(LOCAL_USE_VNDK),)
  my_c_includes += $(JNI_H_INCLUDE)
endif

my_outside_includes := $(filter-out $(OUT_DIR)/%,$(filter /%,$(my_c_includes)))
ifneq ($(my_outside_includes),)
$(error $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): C_INCLUDES must be under the source or output directories: $(my_outside_includes))
endif

# all_objects includes gen_o_objects which were part of LOCAL_GENERATED_SOURCES;
# use normal_objects here to avoid creating circular dependencies. This assumes
# that custom build rules which generate .o files don't consume other generated
# sources as input (or if they do they take care of that dependency themselves).
$(normal_objects) : | $(my_generated_sources)
$(all_objects) : $(import_includes)
ALL_C_CPP_ETC_OBJECTS += $(all_objects)


###########################################################
# Standard library handling.
###########################################################

###########################################################
# The list of libraries that this module will link against are in
# these variables.  Each is a list of bare module names like "libc libm".
#
# LOCAL_SHARED_LIBRARIES
# LOCAL_STATIC_LIBRARIES
# LOCAL_WHOLE_STATIC_LIBRARIES
#
# We need to convert the bare names into the dependencies that
# we'll use for LOCAL_BUILT_MODULE and LOCAL_INSTALLED_MODULE.
# LOCAL_BUILT_MODULE should depend on the BUILT versions of the
# libraries, so that simply building this module doesn't force
# an install of a library.  Similarly, LOCAL_INSTALLED_MODULE
# should depend on the INSTALLED versions of the libraries so
# that they get installed when this module does.
###########################################################
# NOTE:
# WHOLE_STATIC_LIBRARIES are libraries that are pulled into the
# module without leaving anything out, which is useful for turning
# a collection of .a files into a .so file.  Linking against a
# normal STATIC_LIBRARY will only pull in code/symbols that are
# referenced by the module. (see gcc/ld's --whole-archive option)
###########################################################

# Get the list of BUILT libraries, which are under
# various intermediates directories.
so_suffix := $($(my_prefix)SHLIB_SUFFIX)
a_suffix := $($(my_prefix)STATIC_LIB_SUFFIX)

ifneq ($(LOCAL_SDK_VERSION),)
built_shared_libraries := \
    $(foreach lib,$(my_shared_libraries), \
      $(call intermediates-dir-for, \
        SHARED_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/$(lib)$(so_suffix))
built_shared_library_deps := $(addsuffix .toc, $(built_shared_libraries))

# Add the NDK libraries to the built module dependency
my_system_shared_libraries_fullpath := \
    $(my_ndk_stl_shared_lib_fullpath) \
    $(addprefix $(my_ndk_sysroot_lib)/, \
        $(addsuffix $(so_suffix), $(my_system_shared_libraries)))

# We need to preserve the ordering of LOCAL_SHARED_LIBRARIES regardless of
# whether the libs are generated or prebuilt, so we simply can't split into two
# lists and use addprefix.
my_ndk_shared_libraries_fullpath := \
    $(foreach _lib,$(my_ndk_shared_libraries),\
        $(if $(filter $(NDK_MIGRATED_LIBS),$(_lib)),\
            $(my_built_ndk_libs)/$(_lib)$(so_suffix),\
            $(my_ndk_sysroot_lib)/$(_lib)$(so_suffix)))

built_shared_libraries += \
    $(my_ndk_shared_libraries_fullpath) \
    $(my_system_shared_libraries_fullpath) \

else
built_shared_libraries := \
    $(foreach lib,$(installed_shared_library_module_names), \
      $(call intermediates-dir-for, \
        SHARED_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/$(lib)$(so_suffix))
built_shared_library_deps := $(addsuffix .toc, $(built_shared_libraries))
my_system_shared_libraries_fullpath :=
endif

built_static_libraries := \
    $(foreach lib,$(my_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/$(lib)$(a_suffix))

ifdef LOCAL_SDK_VERSION
built_static_libraries += $(my_ndk_stl_static_lib)
endif

built_whole_libraries := \
    $(foreach lib,$(my_whole_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/$(lib)$(a_suffix))

# We don't care about installed static libraries, since the
# libraries have already been linked into the module at that point.
# We do, however, care about the NOTICE files for any static
# libraries that we use. (see notice_files.mk)
installed_static_library_notice_file_targets := \
    $(foreach lib,$(my_static_libraries) $(my_whole_static_libraries), \
      NOTICE-$(if $(LOCAL_IS_HOST_MODULE),HOST$(if $(my_host_cross),_CROSS,),TARGET)-STATIC_LIBRARIES-$(lib))

$(notice_target): | $(installed_static_library_notice_file_targets)
$(LOCAL_INSTALLED_MODULE): | $(notice_target)

# Default is -fno-rtti.
ifeq ($(strip $(LOCAL_RTTI_FLAG)),)
LOCAL_RTTI_FLAG := -fno-rtti
endif

###########################################################
# Rule-specific variable definitions
###########################################################

my_cflags += $(LOCAL_CLANG_CFLAGS)
my_conlyflags += $(LOCAL_CLANG_CONLYFLAGS)
my_cppflags += $(LOCAL_CLANG_CPPFLAGS)
my_asflags += $(LOCAL_CLANG_ASFLAGS)
my_ldflags += $(LOCAL_CLANG_LDFLAGS)
my_cflags += $(LOCAL_CLANG_CFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CLANG_CFLAGS_$(my_32_64_bit_suffix))
my_conlyflags += $(LOCAL_CLANG_CONLYFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CLANG_CONLYFLAGS_$(my_32_64_bit_suffix))
my_cppflags += $(LOCAL_CLANG_CPPFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CLANG_CPPFLAGS_$(my_32_64_bit_suffix))
my_ldflags += $(LOCAL_CLANG_LDFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CLANG_LDFLAGS_$(my_32_64_bit_suffix))
my_asflags += $(LOCAL_CLANG_ASFLAGS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) $(LOCAL_CLANG_ASFLAGS_$(my_32_64_bit_suffix))
my_cflags := $(call convert-to-clang-flags,$(my_cflags))
my_cppflags := $(call convert-to-clang-flags,$(my_cppflags))
my_asflags := $(call convert-to-clang-flags,$(my_asflags))
my_ldflags := $(call convert-to-clang-flags,$(my_ldflags))

ifeq ($(my_fdo_build), true)
  my_cflags := $(patsubst -Os,-O2,$(my_cflags))
  fdo_incompatible_flags := -fno-early-inlining -finline-limit=%
  my_cflags := $(filter-out $(fdo_incompatible_flags),$(my_cflags))
endif

# No one should ever use this flag. On GCC it's mere presence will disable all
# warnings, even those that are specified after it (contrary to typical warning
# flag behavior). This circumvents CFLAGS_NO_OVERRIDE from forcibly enabling the
# warnings that are *always* bugs.
my_illegal_flags := -w
my_cflags := $(filter-out $(my_illegal_flags),$(my_cflags))
my_cppflags := $(filter-out $(my_illegal_flags),$(my_cppflags))
my_conlyflags := $(filter-out $(my_illegal_flags),$(my_conlyflags))

# We can enforce some rules more strictly in the code we own. my_strict
# indicates if this is code that we can be stricter with. If we have rules that
# we want to apply to *our* code (but maybe can't for vendor/device specific
# things), we could extend this to be a ternary value.
my_strict := true
ifneq ($(filter external/%,$(LOCAL_PATH)),)
    my_strict := false
endif

# Can be used to make some annotations stricter for code we can fix (such as
# when we mark functions as deprecated).
ifeq ($(my_strict),true)
    my_cflags += -DANDROID_STRICT
endif

# Check if -Werror or -Wno-error is used in C compiler flags.
# Header libraries do not need cflags.
ifneq (HEADER_LIBRARIES,$(LOCAL_MODULE_CLASS))
  # Prebuilt modules do not need cflags.
  ifeq (,$(LOCAL_PREBUILT_MODULE_FILE))
    my_all_cflags := $(my_cflags) $(my_cppflags) $(my_cflags_no_override)
    # Issue warning if -Wno-error is used.
    ifneq (,$(filter -Wno-error,$(my_all_cflags)))
      $(eval MODULES_USING_WNO_ERROR := $(MODULES_USING_WNO_ERROR) $(LOCAL_MODULE_MAKEFILE):$(LOCAL_MODULE))
    else
      # Issue warning if -Werror is not used. Add it.
      ifeq (,$(filter -Werror,$(my_all_cflags)))
        # Add -Wall -Werror unless the project is in the WARNING_ALLOWED project list.
        ifeq (,$(strip $(call find_warning_allowed_projects,$(LOCAL_PATH))))
          my_cflags := -Wall -Werror $(my_cflags)
        else
          $(eval MODULES_ADDED_WALL := $(MODULES_ADDED_WALL) $(LOCAL_MODULE_MAKEFILE):$(LOCAL_MODULE))
          my_cflags := -Wall $(my_cflags)
        endif
      endif
    endif
  endif
endif

# Disable clang-tidy if it is not found.
ifeq ($(PATH_TO_CLANG_TIDY),)
  my_tidy_enabled := false
else
  # If LOCAL_TIDY is not defined, use global WITH_TIDY
  my_tidy_enabled := $(LOCAL_TIDY)
  ifeq ($(my_tidy_enabled),)
    my_tidy_enabled := $(WITH_TIDY)
  endif
endif

# my_tidy_checks is empty if clang-tidy is disabled.
my_tidy_checks :=
my_tidy_flags :=
ifneq (,$(filter 1 true,$(my_tidy_enabled)))
  tidy_only: $(cpp_objects) $(c_objects) $(gen_c_objects) $(gen_cpp_objects)
  # Set up global default checks
  my_tidy_checks := $(WITH_TIDY_CHECKS)
  ifeq ($(my_tidy_checks),)
    my_tidy_checks := $(call default_global_tidy_checks,$(LOCAL_PATH))
  endif
  # Append local clang-tidy checks.
  ifneq ($(LOCAL_TIDY_CHECKS),)
    my_tidy_checks := $(my_tidy_checks),$(LOCAL_TIDY_CHECKS)
  endif
  my_tidy_flags := $(strip $(WITH_TIDY_FLAGS) $(LOCAL_TIDY_FLAGS))
  # If tidy flags are not specified, default to check all header files.
  ifeq ($(my_tidy_flags),)
    my_tidy_flags := $(call default_tidy_header_filter,$(LOCAL_PATH))
  endif
  # If clang-tidy is not enabled globally, add the -quiet flag.
  ifeq (,$(filter 1 true,$(WITH_TIDY)))
    my_tidy_flags += -quiet -extra-arg-before=-fno-caret-diagnostics
  endif

  ifneq ($(my_tidy_checks),)
    # We might be using the static analyzer through clang-tidy.
    # https://bugs.llvm.org/show_bug.cgi?id=32914
    my_tidy_flags += -extra-arg-before=-D__clang_analyzer__

    # A recent change in clang-tidy (r328258) enabled destructor inlining,
    # which appears to cause a number of false positives. Until that's
    # resolved, this turns off the effects of r328258.
    # https://bugs.llvm.org/show_bug.cgi?id=37459
    my_tidy_flags += -extra-arg-before=-Xclang
    my_tidy_flags += -extra-arg-before=-analyzer-config
    my_tidy_flags += -extra-arg-before=-Xclang
    my_tidy_flags += -extra-arg-before=c++-temp-dtor-inlining=false
  endif
endif

my_tidy_checks := $(subst $(space),,$(my_tidy_checks))

# Add dependency of clang-tidy and clang-tidy.sh
ifneq ($(my_tidy_checks),)
  my_clang_tidy_programs := $(PATH_TO_CLANG_TIDY) $(PATH_TO_CLANG_TIDY_SHELL)
  $(cpp_objects): $(intermediates)/%.o: $(my_clang_tidy_programs)
  $(c_objects): $(intermediates)/%.o: $(my_clang_tidy_programs)
  $(gen_cpp_objects): $(intermediates)/%.o: $(my_clang_tidy_programs)
  $(gen_c_objects): $(intermediates)/%.o: $(my_clang_tidy_programs)
endif

# Move -l* entries from ldflags to ldlibs, and everything else to ldflags
my_ldlib_flags := $(my_ldflags) $(my_ldlibs)
my_ldlibs := $(filter -l%,$(my_ldlib_flags))
my_ldflags := $(filter-out -l%,$(my_ldlib_flags))

# One last verification check for ldlibs
my_allowed_ldlibs :=
ifndef LOCAL_IS_HOST_MODULE
  ifneq ($(LOCAL_SDK_VERSION),)
    my_allowed_ldlibs := $(addprefix -l,$(NDK_PREBUILT_SHARED_LIBRARIES))
  endif
else
  my_allowed_ldlibs := $($(my_prefix)AVAILABLE_LIBRARIES)
endif

my_bad_ldlibs := $(filter-out $(my_allowed_ldlibs),$(my_ldlibs))
ifneq ($(my_bad_ldlibs),)
  $(error $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Bad LOCAL_LDLIBS entries: $(my_bad_ldlibs))
endif

# my_cxx_ldlibs may contain linker flags need to wrap certain libraries
# (start-group/end-group), so append after the check above.
my_ldlibs += $(my_cxx_ldlibs)

###########################################################
## Define PRIVATE_ variables from global vars
###########################################################
ifndef LOCAL_IS_HOST_MODULE
ifdef LOCAL_USE_VNDK
my_target_global_c_includes := \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_INCLUDES)
my_target_global_c_system_includes := \
    $(TARGET_OUT_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_SYSTEM_INCLUDES)
else ifdef LOCAL_SDK_VERSION
my_target_global_c_includes :=
my_target_global_c_system_includes := $(my_ndk_stl_include_path) $(my_ndk_sysroot_include)
else ifdef BOARD_VNDK_VERSION
my_target_global_c_includes := $(SRC_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_INCLUDES) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_INCLUDES)
my_target_global_c_system_includes := $(SRC_SYSTEM_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_SYSTEM_INCLUDES) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_SYSTEM_INCLUDES)
else
my_target_global_c_includes := $(SRC_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_INCLUDES) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_INCLUDES)
my_target_global_c_system_includes := $(SRC_SYSTEM_HEADERS) $(TARGET_OUT_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)PROJECT_SYSTEM_INCLUDES) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_SYSTEM_INCLUDES)
endif

my_target_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CFLAGS)
my_target_global_conlyflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CONLYFLAGS) $(my_c_std_conlyflags)
my_target_global_cppflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CPPFLAGS) $(my_cpp_std_cppflags)
ifeq ($(my_use_clang_lld),true)
  my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_LLDFLAGS)
  include $(BUILD_SYSTEM)/pack_dyn_relocs_setup.mk
  ifeq ($(my_pack_module_relocations),false)
    my_target_global_ldflags += -Wl,--pack-dyn-relocs=none
  endif
else
  my_target_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_LDFLAGS)
endif # my_use_clang_lld

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_GLOBAL_C_INCLUDES := $(my_target_global_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_GLOBAL_C_SYSTEM_INCLUDES := $(my_target_global_c_system_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_CFLAGS := $(my_target_global_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_CONLYFLAGS := $(my_target_global_conlyflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_CPPFLAGS := $(my_target_global_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_GLOBAL_LDFLAGS := $(my_target_global_ldflags)

else # LOCAL_IS_HOST_MODULE

my_host_global_c_includes := $(SRC_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_INCLUDES)
my_host_global_c_system_includes := $(SRC_SYSTEM_HEADERS) \
    $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)C_SYSTEM_INCLUDES)

my_host_global_cflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CFLAGS)
my_host_global_conlyflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CONLYFLAGS) $(my_c_std_conlyflags)
my_host_global_cppflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_CPPFLAGS) $(my_cpp_std_cppflags)
ifeq ($(my_use_clang_lld),true)
  my_host_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_LLDFLAGS)
else
  my_host_global_ldflags := $($(LOCAL_2ND_ARCH_VAR_PREFIX)CLANG_$(my_prefix)GLOBAL_LDFLAGS)
endif # my_use_clang_lld

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_GLOBAL_C_INCLUDES := $(my_host_global_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_GLOBAL_C_SYSTEM_INCLUDES := $(my_host_global_c_system_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_CFLAGS := $(my_host_global_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_CONLYFLAGS := $(my_host_global_conlyflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_CPPFLAGS := $(my_host_global_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HOST_GLOBAL_LDFLAGS := $(my_host_global_ldflags)
endif # LOCAL_IS_HOST_MODULE

# To enable coverage for a given module, set LOCAL_NATIVE_COVERAGE=true and
# build with NATIVE_COVERAGE=true in your enviornment.
ifeq ($(NATIVE_COVERAGE),true)
    ifeq ($(my_native_coverage),true)
        # Note that clang coverage doesn't play nicely with acov out of the box.
        # Clang apparently generates .gcno files that aren't compatible with
        # gcov-4.8.  This can be solved by installing gcc-4.6 and invoking lcov
        # with `--gcov-tool /usr/bin/gcov-4.6`.
        #
        # http://stackoverflow.com/questions/17758126/clang-code-coverage-invalid-output
        my_cflags += --coverage -O0
        my_ldflags += --coverage
    endif

    my_coverage_lib := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBPROFILE_RT)

    $(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_COVERAGE_LIB := $(my_coverage_lib)
    $(LOCAL_INTERMEDIATE_TARGETS): $(my_coverage_lib)
endif

###########################################################
## Define PRIVATE_ variables used by multiple module types
###########################################################
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_NO_DEFAULT_COMPILER_FLAGS := \
    $(strip $(LOCAL_NO_DEFAULT_COMPILER_FLAGS))

ifeq ($(strip $(WITH_STATIC_ANALYZER)),)
  LOCAL_NO_STATIC_ANALYZER := true
endif

ifneq ($(strip $(LOCAL_IS_HOST_MODULE)),)
  my_syntax_arch := host
else
  my_syntax_arch := $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
endif

ifeq ($(strip $(my_cc)),)
  my_cc := $(my_cc_wrapper) $(CLANG)
endif

SYNTAX_TOOLS_PREFIX := \
    $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/libexec

ifneq ($(LOCAL_NO_STATIC_ANALYZER),true)
  my_cc := CCC_CC=$(CLANG) CLANG=$(CLANG) \
           $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CC := $(my_cc)

ifeq ($(strip $(my_cxx)),)
  my_cxx := $(my_cxx_wrapper) $(CLANG_CXX)
endif

ifneq ($(LOCAL_NO_STATIC_ANALYZER),true)
  my_cxx := CCC_CXX=$(CLANG_CXX) CLANG_CXX=$(CLANG_CXX) \
            $(SYNTAX_TOOLS_PREFIX)/c++-analyzer
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LINKER := $(my_linker)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CXX := $(my_cxx)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_YACCFLAGS := $(LOCAL_YACCFLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASFLAGS := $(my_asflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CONLYFLAGS := $(my_conlyflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CFLAGS := $(my_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPPFLAGS := $(my_cppflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CFLAGS_NO_OVERRIDE := $(my_cflags_no_override)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CPPFLAGS_NO_OVERRIDE := $(my_cppflags_no_override)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RTTI_FLAG := $(LOCAL_RTTI_FLAG)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEBUG_CFLAGS := $(debug_cflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_C_INCLUDES := $(my_c_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_IMPORT_INCLUDES := $(import_includes)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDFLAGS := $(my_ldflags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_LDLIBS := $(my_ldlibs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TIDY_CHECKS := $(my_tidy_checks)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TIDY_FLAGS := $(my_tidy_flags)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ARFLAGS := $(my_arflags)

# this is really the way to get the files onto the command line instead
# of using $^, because then LOCAL_ADDITIONAL_DEPENDENCIES doesn't work
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(built_shared_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(built_static_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(built_whole_libraries)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_OBJECTS := $(strip $(all_objects))

###########################################################
# Define library dependencies.
###########################################################
# all_libraries is used for the dependencies on LOCAL_BUILT_MODULE.
all_libraries := \
    $(built_shared_library_deps) \
    $(my_system_shared_libraries_fullpath) \
    $(built_static_libraries) \
    $(built_whole_libraries)

###########################################################
# Export includes
###########################################################
export_includes := $(intermediates)/export_includes
export_cflags := $(foreach d,$(my_export_c_include_dirs),-I $(d))
$(export_includes): PRIVATE_EXPORT_CFLAGS := $(export_cflags)
# Headers exported by whole static libraries are also exported by this library.
export_include_deps := $(strip \
   $(foreach l,$(my_whole_static_libraries), \
     $(call intermediates-dir-for,STATIC_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes))
# Re-export requested headers from shared libraries.
export_include_deps += $(strip \
   $(foreach l,$(LOCAL_EXPORT_SHARED_LIBRARY_HEADERS), \
     $(call intermediates-dir-for,SHARED_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes))
# Re-export requested headers from static libraries.
export_include_deps += $(strip \
   $(foreach l,$(LOCAL_EXPORT_STATIC_LIBRARY_HEADERS), \
     $(call intermediates-dir-for,STATIC_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes))
# Re-export requested headers from header libraries.
export_include_deps += $(strip \
   $(foreach l,$(LOCAL_EXPORT_HEADER_LIBRARY_HEADERS), \
     $(call intermediates-dir-for,HEADER_LIBRARIES,$(l),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))/export_includes))
$(export_includes): PRIVATE_REEXPORTED_INCLUDES := $(export_include_deps)
# By adding $(my_generated_sources) it makes sure the headers get generated
# before any dependent source files get compiled.
$(export_includes) : $(my_export_c_include_deps) $(my_generated_sources) $(export_include_deps) $(LOCAL_EXPORT_C_INCLUDE_DEPS)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@.tmp && touch $@.tmp
ifdef export_cflags
	$(hide) echo "$(PRIVATE_EXPORT_CFLAGS)" >>$@.tmp
endif
ifdef export_include_deps
	$(hide) for f in $(PRIVATE_REEXPORTED_INCLUDES); do \
		cat $$f >> $@.tmp; \
		done
endif
	$(hide) if cmp -s $@.tmp $@ ; then \
	  rm $@.tmp ; \
	else \
	  mv $@.tmp $@ ; \
	fi
export_cflags :=

# Kati adds restat=1 to ninja. GNU make does nothing for this.
.KATI_RESTAT: $(export_includes)

# Make sure export_includes gets generated when you are running mm/mmm
$(LOCAL_BUILT_MODULE) : | $(export_includes)

ifneq (,$(filter-out $(LOCAL_PATH)/%,$(my_export_c_include_dirs)))
my_soong_problems += non_local__export_c_include_dirs
endif

SOONG_CONV.$(LOCAL_MODULE).PROBLEMS := \
    $(SOONG_CONV.$(LOCAL_MODULE).PROBLEMS) $(my_soong_problems)
SOONG_CONV.$(LOCAL_MODULE).DEPS := \
    $(SOONG_CONV.$(LOCAL_MODULE).DEPS) \
    $(filter-out $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_RUNTIME_LIBRARY),\
        $(my_static_libraries) \
        $(my_whole_static_libraries) \
        $(my_shared_libraries) \
        $(my_system_shared_libraries))
SOONG_CONV.$(LOCAL_MODULE).TYPE := native
SOONG_CONV := $(SOONG_CONV) $(LOCAL_MODULE)

###########################################################
# Coverage packaging.
###########################################################
ifeq ($(my_native_coverage),true)
my_gcno_objects := \
    $(cpp_objects) \
    $(gen_cpp_objects) \
    $(c_objects) \
    $(gen_c_objects) \
    $(objc_objects) \
    $(objcpp_objects)

LOCAL_GCNO_FILES := $(patsubst %.o,%.gcno,$(my_gcno_objects))
$(foreach f,$(my_gcno_objects),$(eval $(call gcno-touch-rule,$(f),$(f:.o=.gcno))))
endif
