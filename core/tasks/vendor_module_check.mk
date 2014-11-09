#
# Copyright (C) 2011 The Android Open Source Project
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

# Restrict the vendor module owners here.
_vendor_owner_whitelist := \
        asus \
        audience \
        atmel \
        broadcom \
        csr \
        elan \
        fpc \
        google \
        htc \
        huawei \
        imgtec \
        invensense \
        intel \
        lge \
        moto \
        mtk \
        nvidia \
        nxp \
        nxpsw \
        qcom \
        qti \
        samsung \
        samsung_arm \
        sony \
        synaptics \
        ti \
        trusted_logic \
        widevine


ifneq (,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_RESTRICT_VENDOR_FILES))

_vendor_check_modules := $(product_MODULES)

_vendor_module_owner_info :=

_vendor_module_owner_info_txt := $(call intermediates-dir-for,PACKAGING,vendor_owner_info)/vendor_owner_info.txt
$(_vendor_module_owner_info_txt): PRIVATE_INFO := $(_vendor_module_owner_info)
$(_vendor_module_owner_info_txt):
	@echo "Write vendor module owner info $@"
	@mkdir -p $(dir $@) && rm -f $@
ifdef _vendor_module_owner_info
	@for w in $(PRIVATE_INFO); \
	  do \
	    echo $$w >> $@; \
	done
else
	@echo "No vendor module owner info." > $@
endif

$(call dist-for-goals, droidcore, $(_vendor_module_owner_info_txt))

_vendor_module_owner_info_txt :=
_vendor_module_owner_info :=
_vendor_check_modules :=
endif
