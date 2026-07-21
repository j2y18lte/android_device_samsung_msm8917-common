#!/bin/bash

set -e

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP="${ANDROID_BUILD_TOP:-$(cd "${DEVICE_DIR}/../../.." && pwd)}"

PROJECT="${TOP}/frameworks/base"
PATCH="${DEVICE_DIR}/patches/frameworks_base/0001-Fix-partial-mobile-signal-levels.patch"

if [ ! -d "${PROJECT}/.git" ]; then
    echo "[j2y18lte] frameworks/base not found"
    exit 1
fi

if [ ! -f "${PATCH}" ]; then
    echo "[j2y18lte] patch not found: ${PATCH}"
    exit 1
fi

if git -C "${PROJECT}" apply --reverse --check "${PATCH}" >/dev/null 2>&1; then
    echo "[j2y18lte] SignalDrawable patch already applied"
    exit 0
fi

if git -C "${PROJECT}" apply --check "${PATCH}" >/dev/null 2>&1; then
    git -C "${PROJECT}" apply "${PATCH}"
    echo "[j2y18lte] Applied SignalDrawable patch"
    exit 0
fi

echo "[j2y18lte] ERROR: SignalDrawable patch cannot be applied"
echo "[j2y18lte] Check frameworks/base changes"
exit 1
