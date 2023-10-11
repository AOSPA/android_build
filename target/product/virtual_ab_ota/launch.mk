#
# Copyright (C) 2019 The Android Open-Source Project
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

PRODUCT_VIRTUAL_AB_OTA := true

PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.enabled=true

PRODUCT_PACKAGES += \
    e2fsck_ramdisk \
    resize2fs_ramdisk \
    tune2fs_ramdisk

# For dedicated recovery partitions, we need to include fs tools
PRODUCT_PACKAGES += \
    e2fsck.recovery \
    resize2fs.recovery \
    tune2fs.recovery
