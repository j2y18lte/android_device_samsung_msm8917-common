#!/bin/bash

set -e

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP="${ANDROID_BUILD_TOP:-$(cd "${DEVICE_DIR}/../../.." && pwd)}"

apply_patch() {
    local project_rel="$1"
    local patch_rel="$2"
    local name="$3"
    local project="${TOP}/${project_rel}"
    local patch="${DEVICE_DIR}/patches/${patch_rel}"

    if [ ! -d "${project}/.git" ]; then
        echo "[j2y18lte] ${project_rel} not found"
        return 1
    fi

    if [ ! -f "${patch}" ]; then
        echo "[j2y18lte] patch not found: ${patch}"
        return 1
    fi

    if git -C "${project}" apply --reverse --check "${patch}" >/dev/null 2>&1; then
        echo "[j2y18lte] ${name} patch already applied"
        return 0
    fi

    if git -C "${project}" apply --check "${patch}" >/dev/null 2>&1; then
        git -C "${project}" apply "${patch}"
        echo "[j2y18lte] Applied ${name} patch"
        return 0
    fi

    echo "[j2y18lte] ERROR: ${name} patch cannot be applied"
    echo "[j2y18lte] Check ${project_rel} changes"
    return 1
}

apply_patch \
    "frameworks/base" \
    "frameworks_base/0001-Fix-partial-mobile-signal-levels.patch" \
    "SignalDrawable"

apply_patch \
    "system/bt" \
    "system_bt/0001-avdt-fix-scb-handle-index-calculation.patch" \
    "AVDT SCB handle"
