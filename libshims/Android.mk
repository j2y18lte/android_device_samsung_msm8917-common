LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := \
    pthread_mutex.cpp
LOCAL_SHARED_LIBRARIES := libc
LOCAL_MODULE := libshim_mutexdestroy
LOCAL_VENDOR_MODULE := true
LOCAL_SANITIZE := never
LOCAL_MODULE_TAGS := optional
LOCAL_32_BIT_ONLY := true
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
include $(BUILD_SHARED_LIBRARY)
