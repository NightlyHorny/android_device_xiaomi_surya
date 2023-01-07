LOCAL_PATH := $(call my-dir)
$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET), $(eval $(call add-dependency,$(b),$(call bootimage-to-kernel,$(b)))))

ROOT_BOOT_BIN := $(OUT_DIR)/.magisk/root_boot.sh
BOARD_CUSTOM_BOOTIMG := true
BOARD_PREBUILT_RECOVERY := twrp-3.7.0_12-2-surya-04.12.img
# BOOT.IMG
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH) $(INTERNAL_GKI_CERTIFICATE_DEPS)
	$(call pretty,"Target boot image: $@")
	$(eval kernel := $(call bootimage-to-kernel,$@))
	$(MKBOOTIMG) --kernel $(kernel) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	@/bin/bash $(ROOT_BOOT_BIN) $$PWD/$@
	@cp -v $(OUT_DIR)/.magisk/new-boot.img  $(PRODUCT_OUT)/boot.img
	$(if $(BOARD_GKI_SIGNING_KEY_PATH), \
		$(eval boot_signature := $(call intermediates-dir-for,PACKAGING,generic_boot)/$(notdir $@).boot_signature) \
		$(eval kernel_signature := $(call intermediates-dir-for,PACKAGING,generic_kernel)/$(notdir $(kernel)).boot_signature) \
		$(call generate_generic_boot_image_certificate,$@,$(boot_signature),boot,$(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)) $(newline) \
		$(call generate_generic_boot_image_certificate,$(kernel),$(kernel_signature),generic_kernel,$(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)) $(newline) \
		cat $(kernel_signature) >> $(boot_signature) $(newline) \
		$(call assert-max-image-size,$(boot_signature),16 << 10) $(newline) \
		truncate -s $$(( 16 << 10 )) $(boot_signature) $(newline) \
		cat "$(boot_signature)" >> $@)
	$(call assert-max-image-size,$@,$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$@,boot)))
	$(AVBTOOL) add_hash_footer \
			--image $@ \
			$(call get-partition-size-argument,$(call get-bootimage-partition-size,$@,boot)) \
			--partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
			$(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)

# dont waste time and nerves with PE recovery, just add avb stuff to TWRP
$(INSTALLED_RECOVERYIMAGE_TARGET):
	@echo "++++  Add hash footer to PREBUILT RECOVERY  ++++"
	$(AVBTOOL) add_hash_footer \
	    --image $(BOARD_PREBUILT_RECOVERY) \
	    --partition_size $(BOARD_RECOVERYIMAGE_PARTITION_SIZE) \
	    --partition_name recovery $(INTERNAL_AVB_RECOVERY_SIGNING_ARGS) \
	    $(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)
	@echo "++++  Copying PREBUILT RECOVERY to $(PRODUCT_OUT)  ++++"
	@cp $(BOARD_PREBUILT_RECOVERY) $(PRODUCT_OUT)/recovery.img