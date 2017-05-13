# Configuration for Linux on ARM.
# Generating binaries for the ARMv7-a architecture and higher with NEON
#
ARCH_ARM_HAVE_ARMV7A            := true
ARCH_ARM_HAVE_VFP               := true
ARCH_ARM_HAVE_VFP_D32           := true
ARCH_ARM_HAVE_NEON              := true

local_arch_has_lpae := false

ifneq (,$(filter cortex-a15 krait,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
	# TODO: krait is not a cortex-a15, we set the variant to cortex-a15 so that
	#       hardware divide operations are generated. This should be removed and a
	#       krait CPU variant added to GCC. For clang we specify -mcpu for krait in
	#       core/clang/arm.mk.
	arch_variant_cflags := -mcpu=cortex-a15

	local_arch_has_lpae := true
	arch_variant_ldflags := \
		-Wl,--no-fix-cortex-a8
else
ifneq (,$(filter kryo denver,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
        arch_variant_cflags := -mcpu=cortex-a57

        local_arch_has_lpae := true
        arch_variant_ldflags := \
                -Wl,--no-fix-cortex-a8
else
ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)),cortex-a8)
	arch_variant_cflags := -mcpu=cortex-a8
	arch_variant_ldflags := \
		-Wl,--fix-cortex-a8
else
ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)),cortex-a7)
	arch_variant_cflags := -mcpu=cortex-a7

	local_arch_has_lpae := true
	arch_variant_ldflags := \
		-Wl,--no-fix-cortex-a8
else
ifneq (,$(filter cortex-a53 cortex-a53.a57,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
        arch_variant_cflags := -mcpu=cortex-a53

        local_arch_has_lpae := true
        arch_variant_ldflags := \
                -Wl,--no-fix-cortex-a8
else
	arch_variant_cflags := -march=armv7-a
	# Generic ARM might be a Cortex A8 -- better safe than sorry
	arch_variant_ldflags := \
		-Wl,--fix-cortex-a8
endif
endif
endif
endif
endif

ifeq (true,$(local_arch_has_lpae))
	# Fake an ARM compiler flag as these processors support LPAE which GCC/clang
	# don't advertise.
	# TODO This is a hack and we need to add it for each processor that supports LPAE until some
	# better solution comes around. See Bug 27340895
	arch_variant_cflags += -D__ARM_FEATURE_LPAE=1
endif

local_arch_has_lpae :=

arch_variant_cflags += \
    -mfloat-abi=softfp

ifneq (,$(filter cortex-a7 cortex-a15 krait,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
	arch_variant_cflags += -mfpu=neon-vfpv4
else
ifneq (,$(filter cortex-a53 cortex-a53.a57 kryo denver,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
        arch_variant_cflags += -mfpu=neon-fp-armv8
else
	arch_variant_cflags += -mfpu=neon
endif
endif
