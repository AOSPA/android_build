#
# Copyright (C) 2013 The ParanoidAndroid Project
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

# Sign with the PA keys
# Will not work unless you have the keys

$(TARGET_DIST_PACKAGE) := out/dist/$(TARGET_PRODUCT)-target_files-eng.$(shell whoami).zip



.PHONY: signed
signed: dist
	build/tools/releasetools/sign_target_files_apks -d $(KEYS_DIR) -e $(EXCLUDE_APKS)= out/dist/$(CUSTOM_TARGET_PACKAGE) 
