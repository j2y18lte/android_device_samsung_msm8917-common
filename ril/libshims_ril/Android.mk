LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := ril.c
LOCAL_MODULE := libshims_ril
LOCAL_MODULE_TAGS := optional
LOCAL_VENDOR_MODULE := true
LOCAL_SHARED_LIBRARIES := \
    libcutils \
    liblog
include $(BUILD_SHARED_LIBRARY)