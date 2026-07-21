LOCAL_PATH := $(call my-dir)
RIL_PATH := $(LOCAL_PATH)

ifeq ($(TARGET_DEVICE),j2y18lte)
ifeq ($(BOARD_PROVIDES_LIBRIL),true)
include $(RIL_PATH)/libril/Android.mk
endif
include $(RIL_PATH)/libshims_ril/Android.mk
endif
