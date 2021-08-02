

current_makefile := $(lastword $(MAKEFILE_LIST))

# RAMDISK_SNAPSHOT_VERSION must be set to 'current' in order to generate a ramdisk snapshot.
ifeq ($(RAMDISK_SNAPSHOT_VERSION),current)

.PHONY: ramdisk-snapshot
ramdisk-snapshot: $(SOONG_RAMDISK_SNAPSHOT_ZIP)

$(call dist-for-goals, ramdisk-snapshot, $(SOONG_RAMDISK_SNAPSHOT_ZIP))

else # RAMDISK_SNAPSHOT_VERSION is NOT set to 'current'

.PHONY: ramdisk-snapshot
ramdisk-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
ramdisk-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Ramdisk snapshot. RAMDISK_SNAPSHOT_VERSION must be set to 'current'.")
	exit 1

endif # RAMDISK_SNAPSHOT_VERSION
