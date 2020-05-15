#
# Copyright (C) 2014 The Android Open Source Project
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

# Inherit from this product for devices that support only 64-bit apps using:
# $(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
# The inheritance for this must come before the inheritance chain that leads
# to core_minimal.mk.

# Copy the 64-bit zygote startup script
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote64.rc:system/etc/init/hw/init.zygote64.rc

# Set the zygote property to select the 64-bit script.
# This line must be parsed before the one in core_minimal.mk
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote64

TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_SUPPORTS_64_BIT_APPS := true
