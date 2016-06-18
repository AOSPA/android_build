ifneq (,$(filter cortex-a57.a53 cortex-a53.a57,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
	arch_variant_cflags := -mcpu=cortex-a57.cortex-a53
else
ifneq (,$(filter kryo,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
	arch_variant_cflags := -mcpu=cortex-a57
else
ifneq (,$(filter cortex-a53,$(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
	arch_variant_cflags := -mcpu=cortex-a53
else
	arch_variant_cflags :=
endif

endif

endif
