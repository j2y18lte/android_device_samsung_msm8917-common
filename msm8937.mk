#
# Copyright (C) 2022 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

COMMON_PATH := device/samsung/msm8937-common

$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# Include package config fragments
include $(COMMON_PATH)/product/*.mk

# Include proprietary blobs
$(call inherit-product, vendor/samsung/msm8937-common/msm8937-common-vendor.mk)

# Overlay
DEVICE_PACKAGE_OVERLAYS += $(COMMON_PATH)/overlay
