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
        verizon \
        waves \
        widevine


_restrictions := none

ifneq (,$(_restrictions))
ifneq (,$(PRODUCTS.$(INTERNAL_PRODUCT).VENDOR_PRODUCT_RESTRICT_VENDOR_FILES))
$(error Error: cannot set both PRODUCT_RESTRICT_VENDOR_FILES and VENDOR_PRODUCT_RESTRICT_VENDOR_FILES)
endif
_vendor_exception_path_prefix :=
_vendor_exception_modules :=
else
_restrictions := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).VENDOR_PRODUCT_RESTRICT_VENDOR_FILES))
_vendor_exception_path_prefix := $(patsubst %, vendor/%/%, $(PRODUCTS.$(INTERNAL_PRODUCT).VENDOR_EXCEPTION_PATHS))
_vendor_exception_modules := $(PRODUCTS.$(INTERNAL_PRODUCT).VENDOR_EXCEPTION_MODULES)
endif


ifneq (,$(_restrictions))

_vendor_check_modules := \
$(foreach m, $(filter-out $(_vendor_exception_modules), $(product_MODULES)), \
  $(if $(filter-out FAKE, $(ALL_MODULES.$(m).CLASS)),\
    $(if $(filter vendor/%, $(ALL_MODULES.$(m).PATH)),\
      $(if $(filter-out $(_vendor_exception_path_prefix), $(ALL_MODULES.$(m).PATH)),\
        $(m)))))

_vendor_module_owner_info :=
# Restrict owners
ifneq (,$(filter true owner all, $(_restrictions)))

_vendor_package_overlays := $(filter-out $(_vendor_exception_path_prefix),\
    $(filter vendor/%, $(PRODUCT_PACKAGE_OVERLAYS) $(DEVICE_PACKAGE_OVERLAYS)))
ifneq (,$(_vendor_package_overlays))
$(error Error: Product "$(TARGET_PRODUCT)" cannot have overlay in vendor tree: $(_vendor_package_overlays))
endif
_vendor_package_overlays :=

_vendor_check_copy_files := $(filter-out $(_vendor_exception_path_prefix),\
    $(filter vendor/%, $(PRODUCT_COPY_FILES)))
ifneq (,$(_vendor_check_copy_files))
$(foreach c, $(_vendor_check_copy_files), \
  $(if $(filter $(_vendor_owner_whitelist), $(call word-colon,3,$(c))),,\
    $(error Error: vendor PRODUCT_COPY_FILES file "$(c)" has unknown owner))\
  $(eval _vendor_module_owner_info += $(call word-colon,2,$(c)):$(call word-colon,3,$(c))))
endif
_vendor_check_copy_files :=

$(foreach m, $(_vendor_check_modules), \
  $(if $(filter $(_vendor_owner_whitelist), $(ALL_MODULES.$(m).OWNER)),,\
    $(error Error: vendor module "$(m)" in $(ALL_MODULES.$(m).PATH) with unknown owner \
      "$(ALL_MODULES.$(m).OWNER)" in product "$(TARGET_PRODUCT)"))\
  $(if $(ALL_MODULES.$(m).INSTALLED),\
    $(eval _vendor_module_owner_info += $(patsubst $(PRODUCT_OUT)/%,%,$(ALL_MODULES.$(m).INSTALLED)):$(ALL_MODULES.$(m).OWNER))))

endif


# Restrict paths
ifneq (,$(filter path all, $(_restrictions)))

$(foreach m, $(_vendor_check_modules), \
  $(if $(filter-out ,$(ALL_MODULES.$(m).INSTALLED)),\
    $(if $(filter $(TARGET_OUT_VENDOR)/% $(TARGET_OUT_ODM)/% $(HOST_OUT)/%, $(ALL_MODULES.$(m).INSTALLED)),,\
      $(error Error: vendor module "$(m)" in $(ALL_MODULES.$(m).PATH) \
        in product "$(TARGET_PRODUCT)" being installed to \
        $(ALL_MODULES.$(m).INSTALLED) which is not in the vendor tree or odm tree))))

endif

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
_vendor_exception_path_prefix :=
_vendor_exception_modules :=
_restrictions :=
endif
