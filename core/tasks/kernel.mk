# Android makefile to build the Kernel as a part of the Android build-system
PERL		= perl

KERNEL_TARGET := $(strip $(INSTALLED_KERNEL_TARGET))
ifeq ($(KERNEL_TARGET),)
INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
endif

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := $(TARGET_ARCH)
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

TARGET_KERNEL_HEADER_ARCH := $(strip $(TARGET_KERNEL_HEADER_ARCH))
ifeq ($(TARGET_KERNEL_HEADER_ARCH),)
KERNEL_HEADER_ARCH := $(KERNEL_ARCH)
else
KERNEL_HEADER_ARCH := $(TARGET_KERNEL_HEADER_ARCH)
endif

KERNEL_HEADER_DEFCONFIG := $(strip $(KERNEL_HEADER_DEFCONFIG))
ifeq ($(KERNEL_HEADER_DEFCONFIG),)
KERNEL_HEADER_DEFCONFIG := $(TARGET_KERNEL_CONFIG)
endif

# Force 32-bit binder IPC for 64bit kernel with 32bit userspace
ifeq ($(KERNEL_ARCH),arm64)
ifeq ($(TARGET_ARCH),arm)
KERNEL_CONFIG_OVERRIDE := CONFIG_ANDROID_BINDER_IPC_32BIT=y
endif
endif

ifeq ($(KERNEL_ARCH),arm64)
KERNEL_CROSS_COMPILE := $(ANDROID_BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-androidkernel-
else ifeq ($(KERNEL_ARCH),arm)
KERNEL_CROSS_COMPILE := $(ANDROID_BUILD_TOP)/prebuilts/gcc/$(HOST_OS)-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androidkernel-
else
$(error The target Kernel architecture is not supported)
endif

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_GCC_NOANDROID_CHK := $(shell (echo "int main() {return 0;}" | $(KERNEL_CROSS_COMPILE)gcc -E -mno-android - > /dev/null 2>&1 ; echo $$?))
ifeq ($(strip $(KERNEL_GCC_NOANDROID_CHK)),0)
KERNEL_CFLAGS := KCFLAGS=-mno-android
endif

ifeq ($(HOST_OS),darwin)
    MAKE_FLAGS += C_INCLUDE_PATH=$(ANDROID_BUILD_TOP)/external/elfutils/src/libelf/
endif

# Initialize CCACHE as an empty argument.
CCACHE :=

# Fill the CCACHE argument if USE_CCACHE is not set to false.
ifneq ($(filter-out false,$(USE_CCACHE)),)
    # Detect if the system already has ccache installed.
    CCACHE := $(shell which ccache)

    # Use the prebuilt one if host doesn't have ccache installed.
    ifeq ($(CCACHE),)
        CCACHE := $(ANDROID_BUILD_TOP)/prebuilts/misc/$(HOST_PREBUILT_TAG)/ccache/ccache
        # Check that the executable is here.
        CCACHE := $(strip $(wildcard $(CCACHE)))
    endif

    # Print which ccache is going to be used to build the Kernel.
    $(info Using '$(CCACHE)' binary)
else
# Warn the developer if ccache is set to false.
$(info The usage of ccache is set to '$(USE_CCACHE)')
endif

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config

ifeq ($(TARGET_KERNEL_CONFIG)$(wildcard $(KERNEL_CONFIG)),)
$(error A target Kernel configuration was not defined)
else

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed Kernel image)
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image
else
ifeq ($(KERNEL_ARCH),arm64)
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image.gz
else
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/zImage
endif
endif

ifeq ($(TARGET_KERNEL_APPEND_DTB), true)
$(info Using Kernel with appended DTB image)
TARGET_PREBUILT_INT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)-dtb
endif

KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules

TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
$(info TARGET_PREBUILT_KERNEL is $(TARGET_PREBUILT_KERNEL))

define mv-modules
`mkdir -p $(KERNEL_MODULES_OUT)`; \
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

ifeq ($(HOST_OS),darwin)
  MAKE_FLAGS += C_INCLUDE_PATH=$(ANDROID_BUILD_TOP)/build/core/combo/include/arch/darwin-x86/
endif

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(TARGET_KERNEL_CONFIG)
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding Kernel configuration with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(MAKE) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) oldconfig; fi

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_HEADERS_INSTALL) $(KERNEL_CONFIG)
	$(hide) echo "Building Kernel..."
	$(hide) rm -rf $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/dts
	$(CCACHE) $(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_CFLAGS)
	$(hide) if grep -q 'CONFIG_MODULES=y' $(KERNEL_CONFIG) ; \
		then \
			echo "Building Kernel modules..." ; \
			$(CCACHE) $(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_CFLAGS) modules && \
			$(CCACHE) $(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP=1 ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) modules_install && \
			$(mv-modules) && \
			$(clean-module-folder) ; \
		else \
			echo "The target Kernel configuration has modules disabled" ; \
		fi ;

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(hide) if [ ! -z "$(KERNEL_HEADER_DEFCONFIG)" ]; then \
			rm -f ../$(KERNEL_CONFIG); \
			$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_HEADER_DEFCONFIG); \
			$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_HEADER_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) headers_install; fi
	$(hide) if [ "$(KERNEL_HEADER_DEFCONFIG)" != "$(TARGET_KERNEL_CONFIG)" ]; then \
			echo "Using a different configuration for header generation"; \
			rm -f ../$(KERNEL_CONFIG); \
			$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(TARGET_KERNEL_CONFIG); fi
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding Kernel configuration with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) oldconfig; fi

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) $(MAKE_FLAGS) -C $(TARGET_KERNEL_SOURCE) O=../../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) savedefconfig
	cp $(KERNEL_OUT)/defconfig $(TARGET_KERNEL_SOURCE)/arch/$(KERNEL_ARCH)/configs/$(TARGET_KERNEL_CONFIG)

endif
endif

file := $(INSTALLED_KERNEL_TARGET)
ALL_PREBUILT += $(file)
$(file) : $(TARGET_PREBUILT_INT_KERNEL) | $(ACP)
	$(transform-prebuilt-to-target)

ALL_PREBUILT += $(INSTALLED_KERNEL_TARGET)
