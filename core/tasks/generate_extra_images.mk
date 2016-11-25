# This makefile is used to generate extra images for QCOM targets
# persist, device tree & NAND images required for different QCOM targets.

# These variables are required to make sure that the required
# files/targets are available before generating NAND images.
# This file is included from device/qcom/<TARGET>/AndroidBoard.mk
# and gets parsed before build/core/Makefile, which has these
# variables defined. build/core/Makefile will overwrite these
# variables again.
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img
INSTALLED_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img
INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img
INSTALLED_USERDATAIMAGE_TARGET := $(PRODUCT_OUT)/userdata.img
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
recovery_ramdisk := $(PRODUCT_OUT)/ramdisk-recovery.img
INSTALLED_USBIMAGE_TARGET := $(PRODUCT_OUT)/usbdisk.img
endif

#----------------------------------------------------------------------
# Generate device tree image (dt.img)
#----------------------------------------------------------------------
ifeq ($(strip $(BOARD_KERNEL_SEPARATED_DT)),true)
ifeq ($(strip $(BUILD_TINY_ANDROID)),true)
include device/qcom/common/dtbtool/Android.mk
endif

ifeq ($(strip $(TARGET_CUSTOM_DTBTOOL)),)
DTBTOOL_NAME := dtbTool
else
DTBTOOL_NAME := $(TARGET_CUSTOM_DTBTOOL)
endif

DTBTOOL := $(HOST_OUT_EXECUTABLES)/$(DTBTOOL_NAME)$(HOST_EXECUTABLE_SUFFIX)

INSTALLED_DTIMAGE_TARGET := $(PRODUCT_OUT)/dt.img

possible_dtb_dirs = $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/dts/ $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/
dtb_dir = $(firstword $(wildcard $(possible_dtb_dirs)))

define build-dtimage-target
    $(call pretty,"Target DT image: $(INSTALLED_DTIMAGE_TARGET)")
    $(hide) $(DTBTOOL) -o $@ -s $(BOARD_KERNEL_PAGESIZE) -p $(KERNEL_OUT)/scripts/dtc/ $(dtb_dir)
    $(hide) chmod a+r $@
endef

$(INSTALLED_DTIMAGE_TARGET): $(DTBTOOL) $(INSTALLED_KERNEL_TARGET)
	$(build-dtimage-target)

ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DTIMAGE_TARGET)
ALL_MODULES.$(LOCAL_MODULE).INSTALLED += $(INSTALLED_DTIMAGE_TARGET)
endif

#----------------------------------------------------------------------
# Generate extra userdata images (for variants with multiple MMC sizes)
#----------------------------------------------------------------------
ifneq ($(BOARD_USERDATAEXTRAIMAGE_PARTITION_SIZE),)

ifndef BOARD_USERDATAEXTRAIMAGE_PARTITION_NAME
  BOARD_USERDATAEXTRAIMAGE_PARTITION_NAME := extra
endif

BUILT_USERDATAEXTRAIMAGE_TARGET := $(PRODUCT_OUT)/userdata_$(BOARD_USERDATAEXTRAIMAGE_PARTITION_NAME).img

define build-userdataextraimage-target
    $(call pretty,"Target extra userdata image: $(INSTALLED_USERDATAEXTRAIMAGE_TARGET)")
    @mkdir -p $(TARGET_OUT_DATA)
    $(hide) $(MKEXTUSERIMG) -s $(TARGET_OUT_DATA) $@ ext4 data $(BOARD_USERDATAEXTRAIMAGE_PARTITION_SIZE)
    $(hide) chmod a+r $@
    $(hide) $(call assert-max-image-size,$@,$(BOARD_USERDATAEXTRAIMAGE_PARTITION_SIZE),yaffs)
endef

INSTALLED_USERDATAEXTRAIMAGE_TARGET := $(BUILT_USERDATAEXTRAIMAGE_TARGET)
$(INSTALLED_USERDATAEXTRAIMAGE_TARGET): $(INSTALLED_USERDATAIMAGE_TARGET)
	$(build-userdataextraimage-target)

ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_USERDATAEXTRAIMAGE_TARGET)
ALL_MODULES.$(LOCAL_MODULE).INSTALLED += $(INSTALLED_USERDATAEXTRAIMAGE_TARGET)

endif

.PHONY: aboot
aboot: $(INSTALLED_BOOTLOADER_MODULE)

.PHONY: kernel
kernel: $(INSTALLED_BOOTIMAGE_TARGET)

.PHONY: recoveryimage
recoveryimage: $(INSTALLED_RECOVERYIMAGE_TARGET)
