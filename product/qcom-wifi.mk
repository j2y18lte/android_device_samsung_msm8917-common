# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:system/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:system/etc/permissions/android.hardware.wifi.xml

# WiDi
PRODUCT_PACKAGES += \
    com.android.media.remotedisplay \
    com.android.media.remotedisplay.xml

# Wifi
PRODUCT_PACKAGES += \
    hostapd \
    libQWiFiSoftApCfg \
    libqsap_sdk \
    libwcnss_qmi \
    libwifi-hal-qcom \
    dhcpcd.conf \
    macloader \
    wcnss_service \
    wpa_supplicant \
    wpa_supplicant.conf

# Wifi configuration files
PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/configs/wifi/hostapd.accept:system/etc/hostapd/hostapd.accept \
    $(COMMON_PATH)/configs/wifi/hostapd_default.conf:system/etc/hostapd/hostapd_default.conf \
    $(COMMON_PATH)/configs/wifi/hostapd.deny:system/etc/hostapd/hostapd.deny \
    $(COMMON_PATH)/configs/wifi/p2p_supplicant_overlay.conf:system/etc/wifi/p2p_supplicant_overlay.conf \
    $(COMMON_PATH)/configs/wifi/wpa_supplicant_overlay.conf:system/etc/wifi/wpa_supplicant_overlay.conf \
    $(COMMON_PATH)/configs/wifi/prima/WCNSS_cfg.dat:system/etc/firmware/wlan/prima/WCNSS_cfg.dat \
    $(COMMON_PATH)/configs/wifi/prima/WCNSS_qcom_cfg.ini:system/etc/firmware/wlan/prima/WCNSS_qcom_cfg.ini \
    $(COMMON_PATH)/configs/wifi/prima/WCNSS_qcom_cfg.ini:system/etc/wifi/WCNSS_qcom_cfg.ini \
    $(COMMON_PATH)/configs/wifi/prima/WCNSS_qcom_wlan_nv.bin:system/etc/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin
