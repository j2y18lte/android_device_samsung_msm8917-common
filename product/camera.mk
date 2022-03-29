# Camera
PRODUCT_PACKAGES += \
    Snap

# Samsung Camera Libraries
PRODUCT_PACKAGES += \
    camera.msm8937

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.camera.front.xml:system/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:system/etc/permissions/android.hardware.camera.flash-autofocus.xml
