# Audio
PRODUCT_PACKAGES += \
    audiod \
    audio.a2dp.default \
    audio.primary.msm8937 \
    audio_policy.default.so \
    audio.primary.default \
    audio.r_submix.default \
    audio.usb.default \
    libaudio-resampler \
    libaudioroute \
    libqcompostprocbundle \
    libqcomvisualizer \
    libqcomvoiceprocessing \
    libtinycompress \
    tinymix \
    libtinyalsa

# Audio configuration files
PRODUCT_COPY_FILES += \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/aanc_tuning_mixer.txt:system/etc/aanc_tuning_mixer.txt \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_effects.conf:system/vendor/etc/audio_effects.conf \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_platform_info.xml:system/etc/audio_platform_info.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_platform_info_extcodec.xml:system/etc/audio_platform_info_extcodec.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_output_policy.conf:system/etc/audio_output_policy.conf \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_policy.conf:system/etc/audio_policy.conf

PRODUCT_COPY_FILES += \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_mtp.xml:system/etc/mixer_paths_mtp.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_sku3.xml:system/etc/mixer_paths_qrd_sku3.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_skuh.xml:system/etc/mixer_paths_qrd_skuh.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_skuhf.xml:system/etc/mixer_paths_qrd_skuhf.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_skui.xml:system/etc/mixer_paths_qrd_skui.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_skum.xml:system/etc/mixer_paths_qrd_skum.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_qrd_skun.xml:system/etc/mixer_paths_qrd_skun.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_skuk.xml:system/etc/mixer_paths_skuk.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_wcd9306.xml:system/etc/mixer_paths_wcd9306.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_wcd9326.xml:system/etc/mixer_paths_wcd9326.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_wcd9330.xml:system/etc/mixer_paths_wcd9330.xml \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/mixer_paths_wcd9335.xml:system/etc/mixer_paths_wcd9335.xml

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:system/etc/permissions/android.hardware.audio.low_latency.xml

# XML Audio configuration files
PRODUCT_COPY_FILES += \
    hardware/qcom/audio-caf/msm8996/configs/msm8937/audio_policy_configuration.xml:system/etc/audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/a2dp_audio_policy_configuration.xml:system/etc/a2dp_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:system/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:system/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:system/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:system/etc/usb_audio_policy_configuration.xml
