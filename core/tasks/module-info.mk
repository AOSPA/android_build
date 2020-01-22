# Print a list of the modules that could be built

MODULE_INFO_JSON := $(PRODUCT_OUT)/module-info.json

$(MODULE_INFO_JSON):
	@echo Generating $@
	$(foreach m, $(sort $(ALL_MODULES)), $(eval ALL_MODULES.$(m).INCS := \
					$(patsubst -D%,,$(subst -I,,$(foreach imp,$(ALL_MODULES.$(m).IMPORTS), \
					$(EXPORTS.$(imp).FLAGS))) $(ALL_MODULES.$(m).INCS))))
	$(hide) echo -ne '{\n ' > $@
	$(hide) echo -ne $(foreach m, $(sort $(ALL_MODULES)), \
		' "$(m)": {' \
			'"class": [$(foreach w,$(sort $(ALL_MODULES.$(m).CLASS)),"$(w)", )], ' \
			'"path": [$(foreach w,$(sort $(ALL_MODULES.$(m).PATH)),"$(w)", )], ' \
			'"tags": [$(foreach w,$(sort $(ALL_MODULES.$(m).TAGS)),"$(w)", )], ' \
			'"installed": [$(foreach w,$(sort $(ALL_MODULES.$(m).INSTALLED)),"$(w)", )], ' \
			'"compatibility_suites": [$(foreach w,$(sort $(ALL_MODULES.$(m).COMPATIBILITY_SUITES)),"$(w)", )], ' \
			'"auto_test_config": [$(ALL_MODULES.$(m).auto_test_config)], ' \
			'"module_name": "$(ALL_MODULES.$(m).MODULE_NAME)", ' \
			'"test_config": [$(if $(ALL_MODULES.$(m).TEST_CONFIG),"$(ALL_MODULES.$(m).TEST_CONFIG)")], ' \
			'"dependencies": [$(foreach w,$(sort $(ALL_DEPS.$(m).ALL_DEPS)),"$(w)", )], ' \
			'"srcs": [$(foreach w,$(sort $(ALL_MODULES.$(m).SRCS)),"$(w)", )], ' \
			'"incs": [$(foreach w,$(sort $(ALL_MODULES.$(m).INCS)),"$(w)", )], ' \
                        '"static": [$(foreach w,$(sort $(ALL_MODULES.$(m).STATIC)),"$(w)", )], ' \
                        '"wstatic": [$(foreach w,$(sort $(ALL_MODULES.$(m).WSTATIC)),"$(w)", )], ' \
                        '"export": [$(foreach w,$(sort $(ALL_MODULES.$(m).EXPORT)),"$(w)", )], ' \
                        '"cflags": [$(foreach w,$(sort $(ALL_MODULES.$(m).CFLAGS)),"$(w)", )], ' \
                        '"abi_checker": [$(foreach w,$(sort $(ALL_MODULES.$(m).ABI_CHECKER)),"$(w)", )], ' \
			'"srcjars": [$(foreach w,$(sort $(ALL_MODULES.$(m).SRCJARS)),"$(w)", )], ' \
			'"classes_jar": [$(foreach w,$(sort $(ALL_MODULES.$(m).CLASSES_JAR)),"$(w)", )], ' \
			'},\n' \
	 ) | sed -e 's/, *\]/]/g' -e 's/, *\}/ }/g' -e '$$s/,$$//' >> $@
	$(hide) echo '}' >> $@


droidcore: $(MODULE_INFO_JSON)

$(call dist-for-goals, general-tests, $(MODULE_INFO_JSON))
