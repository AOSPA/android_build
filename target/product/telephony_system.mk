#
# Copyright (C) 2018 The Android Open Source Project
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

# This is the list of modules that are specific to products that have telephony
# hardware, and install on the system partition.

# Set flag to enable compilation of vendor value-adds to Android Telephony.
TARGET_USES_QCOM_BSP_ATEL := true

PRODUCT_PACKAGES := \

ifneq ($(TARGET_NO_TELEPHONY), true)
PRODUCT_PACKAGES += \
    ONS \
    CarrierDefaultApp \
    CallLogBackup \
    com.android.cellbroadcast \
    CellBroadcastLegacyApp
endif #TARGET_NO_TELEPHONY

PRODUCT_COPY_FILES := \
