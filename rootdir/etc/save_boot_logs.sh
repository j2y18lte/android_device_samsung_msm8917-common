#!/system/bin/sh
#
# j2y18lte continuous boot / FDE / hardware log collector
#
# Starts automatically as soon as the real /data becomes available.
# There is no timer, stop file, manual trigger, or archive.
#
# Current boot:
#   /data/local/tmp/log/
#
# Previous boot:
#   /data/local/tmp/log.previous/
#
# Logs remain as ordinary files after shutdown. logcat is rotated to prevent
# unlimited growth.
#

BASE="/data/local/tmp"
LOGDIR="$BASE/log"
PREV_LOGDIR="$BASE/log.previous"
LOCKDIR="$BASE/.save_boot_logs.lock"

TIMELINE_INTERVAL=10
QUICK_SNAPSHOT_INTERVAL=60
FULL_SNAPSHOT_INTERVAL=300
LOGCAT_ROTATE_KB=32768
LOGCAT_ROTATE_COUNT=8
MAX_CONFIG_BYTES=2097152
MAX_CRASH_FILES=20
MAX_CRASH_BYTES=2097152

LOGCAT_PID=""
KERNEL_LOG_PID=""

have()
{
    command -v "$1" >/dev/null 2>&1
}

kmsg()
{
    echo "SAVE_LOGS: $*" > /dev/kmsg 2>/dev/null
}

section()
{
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

capture_sh()
{
    OUT="$1"
    shift
    CMD="$*"

    mkdir -p "$(dirname "$OUT")"
    {
        echo "date=$(date)"
        echo "command=$CMD"
        echo
        /system/bin/sh -c "$CMD"
        RC=$?
        echo
        echo "exit_code=$RC"
    } > "$OUT" 2>&1
}

capture_cmd()
{
    OUT="$1"
    shift

    mkdir -p "$(dirname "$OUT")"
    {
        echo "date=$(date)"
        echo "command=$*"
        echo
        "$@"
        RC=$?
        echo
        echo "exit_code=$RC"
    } > "$OUT" 2>&1
}

read_path()
{
    PATHNAME="$1"
    LABEL="$2"

    echo "--- $LABEL: $PATHNAME ---"
    if [ -e "$PATHNAME" ]; then
        cat "$PATHNAME" 2>&1
    else
        echo "MISSING"
    fi
}

cleanup()
{
    if [ -n "$LOGCAT_PID" ]; then
        kill "$LOGCAT_PID" 2>/dev/null
        wait "$LOGCAT_PID" 2>/dev/null
    fi

    if [ -n "$KERNEL_LOG_PID" ]; then
        kill "$KERNEL_LOG_PID" 2>/dev/null
        wait "$KERNEL_LOG_PID" 2>/dev/null
    fi

    rm -rf "$LOCKDIR" 2>/dev/null
}

acquire_lock()
{
    mkdir -p "$BASE"

    if [ -d "$LOCKDIR" ]; then
        OLD_PID=$(cat "$LOCKDIR/pid" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            kmsg "collector already running pid=$OLD_PID"
            exit 0
        fi
        rm -rf "$LOCKDIR"
    fi

    mkdir "$LOCKDIR" 2>/dev/null || exit 0
    echo $$ > "$LOCKDIR/pid"
}

save_pstore()
{
    PDIR="$LOGDIR/01_boot/pstore"
    mkdir -p "$PDIR"

    if [ -f /proc/last_kmsg ]; then
        cat /proc/last_kmsg > "$PDIR/last_kmsg.txt" 2>&1
    else
        echo "MISSING /proc/last_kmsg" > "$PDIR/last_kmsg.txt"
    fi

    FOUND=0
    for FILE in /sys/fs/pstore/*; do
        [ -f "$FILE" ] || continue
        FOUND=1
        cp -p "$FILE" "$PDIR/$(basename "$FILE").txt" 2>/dev/null
    done

    [ "$FOUND" -eq 1 ] || echo "MISSING /sys/fs/pstore files" > "$PDIR/pstore_missing.txt"
}

save_process_details()
{
    OUTDIR="$1/process_details"
    mkdir -p "$OUTDIR"

    for PROC in /proc/[0-9]*; do
        [ -r "$PROC/cmdline" ] || continue
        PID=$(basename "$PROC")
        CMDLINE=$(tr '\000' ' ' < "$PROC/cmdline" 2>/dev/null)

        echo "$CMDLINE" | grep -iE \
            "qsee|keymaster|audio|camera|media|sensor|bluetooth|rild|radio|gnss|gps|surfaceflinger|composer|servicemanager|vold" \
            >/dev/null 2>&1 || continue

        SAFE=$(echo "$CMDLINE" | tr '/ @:' '____' | cut -c1-80)
        [ -n "$SAFE" ] || SAFE="pid_$PID"
        FILE="$OUTDIR/${PID}_${SAFE}.txt"

        {
            echo "pid=$PID"
            echo "cmdline=$CMDLINE"
            echo
            echo "=== STATUS ==="
            cat "$PROC/status" 2>&1
            echo
            echo "=== WCHAN ==="
            cat "$PROC/wchan" 2>&1
            echo
            echo "=== LIMITS ==="
            cat "$PROC/limits" 2>&1
            echo
            echo "=== MAPS FILTERED ==="
            grep -iE \
                "keymaster|qsee|camera|audio|sensor|bluetooth|hidl|binder|vendor/lib|system/lib" \
                "$PROC/maps" 2>/dev/null
            echo
            echo "=== FD ==="
            ls -lZ "$PROC/fd" 2>&1
        } > "$FILE" 2>&1
    done
}

snapshot_general()
{
    D="$1/general"
    mkdir -p "$D"

    capture_sh "$D/identity.txt" '
        uname -a
        echo
        cat /proc/version 2>/dev/null
        echo
        cat /proc/cmdline 2>/dev/null
        echo
        echo "fingerprint=$(getprop ro.build.fingerprint)"
        echo "description=$(getprop ro.build.description)"
        echo "device=$(getprop ro.product.device)"
        echo "board=$(getprop ro.product.board)"
        echo "platform=$(getprop ro.board.platform)"
        echo "hardware=$(getprop ro.hardware)"
        echo "security_patch=$(getprop ro.build.version.security_patch)"
        echo "boot_reason=$(getprop ro.boot.bootreason)"
        echo "verified_boot=$(getprop ro.boot.verifiedbootstate)"
        echo "selinux=$(getenforce 2>/dev/null)"
        echo "uptime=$(cat /proc/uptime)"
    '

    capture_sh "$D/getprop.txt" 'getprop | sort'
    capture_sh "$D/init_services.txt" 'getprop | grep "init.svc" | sort'
    capture_sh "$D/processes.txt" '
        echo "=== ps -A ==="
        ps -A
        echo
        echo "=== ps -AZ ==="
        ps -AZ 2>/dev/null
        echo
        echo "=== ps -A -T ==="
        ps -A -T 2>/dev/null
    '
    capture_sh "$D/service_list.txt" 'service list'
    capture_sh "$D/dumpsys_list.txt" 'dumpsys -l'
    capture_sh "$D/lshal.txt" '
        if command -v lshal >/dev/null 2>&1; then
            lshal
        elif [ -x /system/bin/lshal ]; then
            /system/bin/lshal
        else
            echo "MISSING lshal"
        fi
    '
    capture_sh "$D/memory.txt" '
        cat /proc/meminfo
        echo
        free -m 2>/dev/null
        echo
        dumpsys meminfo 2>/dev/null
    '
    capture_sh "$D/kernel_runtime.txt" '
        cat /proc/interrupts
        echo
        cat /proc/modules
        echo
        cat /proc/softirqs
        echo
        cat /proc/pressure/cpu 2>/dev/null
        cat /proc/pressure/memory 2>/dev/null
        cat /proc/pressure/io 2>/dev/null
    '

    save_process_details "$1"
}

snapshot_fde_qsee()
{
    D="$1/fde_qsee"
    mkdir -p "$D"

    capture_sh "$D/crypto_properties.txt" '
        getprop | grep -iE "crypto|vold|decrypt|encrypt|keymaster|qsee|listener|keystore" | sort
        echo
        echo "ro.crypto.state=$(getprop ro.crypto.state)"
        echo "ro.crypto.type=$(getprop ro.crypto.type)"
        echo "ro.crypto.fs_crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
        echo "vold.decrypt=$(getprop vold.decrypt)"
        echo "vold.post_fs_data_done=$(getprop vold.post_fs_data_done)"
        echo "listeners=$(getprop vendor.sys.listeners.registered)"
        echo "qsee_enable=$(getprop vendor.sys.qseecomd.enable)"
    '

    capture_sh "$D/dmcrypt.txt" '
        echo "=== DM DEVICES ==="
        ls -laZ /dev/block/dm-* /dev/block/mapper 2>&1
        echo
        echo "=== SYSFS DM ==="
        for N in /sys/block/dm-*; do
            [ -e "$N" ] || continue
            echo "--- $N ---"
            find "$N/dm" -maxdepth 1 -type f -exec sh -c "echo ==== \$1; cat \$1" sh {} \; 2>/dev/null
        done
        echo
        echo "=== DMSETUP ==="
        if command -v dmsetup >/dev/null 2>&1; then
            dmsetup ls --tree 2>&1
            dmsetup table 2>&1
            dmsetup status 2>&1
            dmsetup info -c 2>&1
        else
            echo "MISSING dmsetup"
        fi
    '

    capture_sh "$D/qsee_devices.txt" '
        ls -lZ \
            /dev/binder /dev/hwbinder /dev/vndbinder \
            /dev/qseecom /dev/ion /dev/block/mmcblk0rpmb \
            2>&1
        echo
        ls -ldZ /persist /firmware /vendor/firmware_mnt 2>&1
        echo
        mount | grep -iE "persist|firmware|apnhlos|modem"
    '

    capture_sh "$D/qsee_keymaster_services.txt" '
        ps -A | grep -iE "qsee|keymaster|keystore|servicemanager"
        echo
        getprop | grep -iE "init.svc.*(qsee|keymaster|keystore|servicemanager)"
        echo
        service list | grep -iE "keymaster|keystore"
        echo
        if command -v lshal >/dev/null 2>&1; then
            lshal | grep -iE "keymaster|gatekeeper|drm"
        fi
    '

    capture_sh "$D/data_transition_state.txt" '
        echo "=== MOUNTS ==="
        cat /proc/mounts | grep -E " /data |/mnt/runtime|/storage/emulated|dm-"
        echo
        echo "=== CRITICAL DATA PATHS ==="
        ls -ldZ \
            /data \
            /data/system \
            /data/system/users \
            /data/misc \
            /data/misc/camera \
            /data/vendor \
            /data/vendor/misc \
            /data/vendor/misc/audio \
            /data/vendor/misc/audio/acdbdata \
            /data/vendor/misc/audio/acdbdata/delta \
            /data/media \
            /data/media/0 \
            2>&1
        echo
        echo "camera_target=$(readlink -f /data/misc/camera 2>/dev/null)"
        echo
        echo "=== RESTORECON DRY RUN ==="
        restorecon -nRF /data/misc/camera /data/vendor/misc/audio 2>&1
    '

    capture_sh "$D/proc_crypto.txt" 'cat /proc/crypto'
}

snapshot_storage()
{
    D="$1/storage"
    mkdir -p "$D"

    capture_sh "$D/mounts.txt" '
        cat /proc/mounts
        echo
        mount
        echo
        df -h 2>/dev/null
        echo
        df -i 2>/dev/null
    '
    capture_sh "$D/vold.txt" '
        dumpsys mount 2>&1
        echo
        dumpsys vold 2>&1
        echo
        sm list-disks 2>&1
        sm list-volumes all 2>&1
    '
    capture_sh "$D/block_devices.txt" '
        cat /proc/partitions
        echo
        ls -la /dev/block/bootdevice/by-name 2>&1
        echo
        ls -la /dev/block/platform/*/by-name 2>&1
        echo
        for B in /sys/class/block/*; do
            [ -e "$B" ] || continue
            echo "$(basename "$B") size=$(cat "$B/size" 2>/dev/null) dev=$(cat "$B/dev" 2>/dev/null)"
        done
    '
    capture_sh "$D/media_storage.txt" '
        ls -ldZ \
            /data/media /data/media/0 \
            /storage /storage/emulated /storage/emulated/0 \
            /sdcard /mnt/runtime/default/emulated/0 \
            2>&1
        echo
        find /data/media/0 /storage/emulated/0 \
            -maxdepth 3 -type f -mmin -60 -ls 2>/dev/null | head -n 300
    '
    capture_sh "$D/mediastore.txt" '
        content query --uri content://media/external/images/media \
            --projection _id:_data:_display_name:mime_type:date_added \
            --sort "date_added DESC" 2>&1 | head -n 150
        echo
        content query --uri content://media/external/video/media \
            --projection _id:_data:_display_name:mime_type:date_added \
            --sort "date_added DESC" 2>&1 | head -n 150
    '
}

snapshot_audio()
{
    D="$1/audio"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        echo "=== PROCESSES ==="
        ps -A | grep -iE "audio|audioserver|acdb|voice|soundtrigger"
        echo
        echo "=== SERVICES ==="
        getprop | grep -iE "init.svc.*(audio|acdb|voice|sound)"
        echo
        service list | grep -iE "audio|soundtrigger"
        echo
        echo "=== PROPERTIES ==="
        getprop | grep -iE "audio|voice|acdb|sound|fluenc|snd" | sort
        echo
        echo "=== DATA PATHS ==="
        ls -ldZ \
            /data/vendor/misc/audio \
            /data/vendor/misc/audio/acdbdata \
            /data/vendor/misc/audio/acdbdata/delta \
            /data/misc/audio \
            2>&1
        find /data/vendor/misc/audio /data/misc/audio -maxdepth 3 -ls 2>/dev/null
    '
    capture_sh "$D/devices.txt" '
        ls -laZ /dev/snd 2>&1
        echo
        for F in /proc/asound/cards /proc/asound/devices /proc/asound/pcm /proc/asound/version /proc/asound/modules; do
            echo "--- $F ---"
            cat "$F" 2>&1
        done
    '
    capture_sh "$D/tinymix.txt" '
        if command -v tinymix >/dev/null 2>&1; then
            tinymix
        else
            echo "MISSING tinymix"
        fi
    '
    capture_sh "$D/dumpsys_audio.txt" 'dumpsys audio'
    capture_sh "$D/audio_flinger.txt" 'dumpsys media.audio_flinger'
    capture_sh "$D/audio_policy.txt" 'dumpsys media.audio_policy'
    capture_sh "$D/audio_effects.txt" 'dumpsys media.audio_flinger --effects 2>&1'
    capture_sh "$D/soundtrigger.txt" 'dumpsys soundtrigger 2>&1; dumpsys media.sound_trigger_hw 2>&1'
}

snapshot_camera()
{
    D="$1/camera"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        echo "=== PROCESSES ==="
        ps -A | grep -iE "camera|snap|jpeg|provider|media"
        echo
        echo "=== SERVICES ==="
        getprop | grep -iE "init.svc.*(camera|jpeg|media)"
        echo
        service list | grep -iE "camera|media.camera"
        echo
        echo "=== PROPERTIES ==="
        getprop | grep -iE "camera|jpeg|camx|mmcamera|media" | sort
        echo
        echo "=== CAMERA CONFIG PATHS ==="
        ls -ldZ /data/misc/camera /system/etc/camera /vendor/etc/camera 2>&1
        echo "data_camera_target=$(readlink -f /data/misc/camera 2>/dev/null)"
        find /data/misc/camera /system/etc/camera /vendor/etc/camera \
            -maxdepth 3 -type f -ls 2>/dev/null | head -n 500
    '
    capture_sh "$D/device_nodes.txt" '
        ls -laZ /dev/media* /dev/video* /dev/v4l-subdev* /dev/msm_camera* 2>&1
        echo
        for NODE in /sys/class/video4linux/*; do
            [ -e "$NODE" ] || continue
            echo "--- $NODE ---"
            cat "$NODE/name" 2>/dev/null
            readlink -f "$NODE/device" 2>/dev/null
        done
    '
    capture_sh "$D/media_camera.txt" 'dumpsys media.camera'
    capture_sh "$D/camera_package.txt" '
        dumpsys package org.lineageos.snap 2>&1
        dumpsys package com.android.camera2 2>&1
        dumpsys package com.android.camera 2>&1
    '
}

snapshot_media()
{
    D="$1/media"
    mkdir -p "$D"

    capture_sh "$D/processes_services.txt" '
        ps -A | grep -iE "media|codec|extractor|drm|omx"
        echo
        getprop | grep -iE "init.svc.*(media|codec|extractor|drm)"
        echo
        service list | grep -iE "media|codec|drm"
    '
    capture_sh "$D/media_codec.txt" 'dumpsys media.codec 2>&1'
    capture_sh "$D/media_extractor.txt" 'dumpsys media.extractor 2>&1'
    capture_sh "$D/media_metrics.txt" 'dumpsys media.metrics 2>&1'
    capture_sh "$D/media_player.txt" 'dumpsys media.player 2>&1'
    capture_sh "$D/drm.txt" 'dumpsys drm.drmManager 2>&1; dumpsys media.drm 2>&1'
}

snapshot_sensors_input()
{
    D="$1/sensors_input"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        ps -A | grep -iE "sensor|context_hub|inputflinger"
        echo
        getprop | grep -iE "sensor|persist.vendor.sensors|init.svc.*sensor" | sort
        echo
        service list | grep -iE "sensor|input"
        echo
        ls -laZ /dev/input /dev/iio* /dev/sensors 2>&1
        echo
        find /sys/class/sensors /sys/bus/iio/devices -maxdepth 3 -type f 2>/dev/null | head -n 500
    '
    capture_sh "$D/sensorservice.txt" 'dumpsys sensorservice'
    capture_sh "$D/input.txt" 'dumpsys input'
    capture_sh "$D/input_devices.txt" 'cat /proc/bus/input/devices; getevent -lp 2>/dev/null'
}

snapshot_bluetooth()
{
    D="$1/bluetooth"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        getprop | grep -iE "bluetooth|persist.vendor.bt|ro.bt|bt\." | sort
        echo
        ps -A | grep -iE "bluetooth|bt_logger|hci|wcnss"
        echo
        getprop | grep -iE "init.svc.*(bluetooth|bt|wcnss)"
        echo
        service list | grep -i bluetooth
        echo
        settings get global bluetooth_on 2>/dev/null
    '
    capture_sh "$D/manager.txt" 'dumpsys bluetooth_manager'
    capture_sh "$D/a2dp.txt" 'dumpsys bluetooth_a2dp 2>&1'
    capture_sh "$D/headset.txt" 'dumpsys bluetooth_headset 2>&1'
}

snapshot_radio()
{
    D="$1/radio"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        getprop | grep -iE "gsm\.|ril\.|radio\.|telephony|operator|baseband|sim" | sort
        echo
        ps -A | grep -iE "rild|ims|qcril|radio|netmgr|ipacm|qti"
        echo
        getprop | grep -iE "init.svc.*(ril|radio|ims|netmgr|ipacm)"
        echo
        service list | grep -iE "phone|isub|iphonesubinfo|telephony|carrier|ims"
    '
    capture_sh "$D/telephony_registry.txt" 'dumpsys telephony.registry'
    capture_sh "$D/telecom.txt" 'dumpsys telecom'
    capture_sh "$D/subscriptions.txt" 'dumpsys isub 2>&1; content query --uri content://telephony/siminfo 2>&1'
    capture_sh "$D/phone_info.txt" 'dumpsys iphonesubinfo 2>&1'
    capture_sh "$D/carrier_config.txt" 'dumpsys carrier_config 2>&1'
    capture_sh "$D/default_subscriptions.txt" '
        settings get global multi_sim_voice_call
        settings get global multi_sim_sms
        settings get global multi_sim_data_call
        settings get global preferred_network_mode
    '
}

snapshot_wifi_network_gps()
{
    D="$1/network_gps"
    mkdir -p "$D"

    capture_sh "$D/network_state.txt" '
        ip addr 2>&1
        echo
        ip route show table all 2>&1
        echo
        ip rule 2>&1
        echo
        cat /proc/net/route 2>&1
        echo
        cat /proc/net/ipv6_route 2>&1
    '
    capture_sh "$D/firewall.txt" '
        iptables-save 2>&1
        echo
        ip6tables-save 2>&1
    '
    capture_sh "$D/connectivity.txt" 'dumpsys connectivity'
    capture_sh "$D/netd.txt" 'dumpsys netd 2>&1; dumpsys network_management 2>&1'
    capture_sh "$D/wifi.txt" '
        getprop | grep -iE "wifi|wlan|wcnss|cnss" | sort
        echo
        ps -A | grep -iE "wifi|wpa|hostapd|wcnss|cnss"
        echo
        dumpsys wifi 2>&1
        echo
        dumpsys wificond 2>&1
    '
    capture_sh "$D/gps_location.txt" '
        getprop | grep -iE "gps|gnss|location|izat" | sort
        echo
        ps -A | grep -iE "gps|gnss|izat|location"
        echo
        service list | grep -iE "location|gnss|gps"
        echo
        dumpsys location 2>&1
        echo
        dumpsys gnss 2>&1
    '
}

snapshot_usb()
{
    D="$1/usb"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        getprop | grep -iE "usb|adb" | sort
        echo
        echo "sys.usb.config=$(getprop sys.usb.config)"
        echo "sys.usb.state=$(getprop sys.usb.state)"
        echo "persist.sys.usb.config=$(getprop persist.sys.usb.config)"
        echo "sys.usb.configfs=$(getprop sys.usb.configfs)"
        echo "sys.usb.controller=$(getprop sys.usb.controller)"
        echo "adbd=$(getprop init.svc.adbd)"
        echo
        ps -A | grep -iE "adbd|mtp|usb"
        echo
        ls -lZ /dev/mtp_usb /dev/usb-ffs /dev/socket/adbd 2>&1
    '
    capture_sh "$D/legacy_gadget.txt" '
        ls -laZ /sys/class/android_usb/android0 2>&1
        for NODE in enable idVendor idProduct functions state; do
            echo "--- $NODE ---"
            cat "/sys/class/android_usb/android0/$NODE" 2>&1
        done
    '
    capture_sh "$D/configfs.txt" '
        find /config/usb_gadget -maxdepth 5 -ls 2>&1
        find /sys/kernel/config/usb_gadget -maxdepth 5 -ls 2>&1
    '
    capture_sh "$D/dumpsys_usb.txt" 'dumpsys usb'
}

snapshot_display()
{
    D="$1/display"
    mkdir -p "$D"

    capture_sh "$D/state.txt" '
        getprop | grep -iE "display|graphics|surfaceflinger|hwc|composer|gralloc|light|brightness" | sort
        echo
        ps -A | grep -iE "surfaceflinger|composer|display|lights"
        echo
        getprop | grep -iE "init.svc.*(surfaceflinger|composer|display|light)"
        echo
        for F in \
            /sys/class/graphics/fb0/name \
            /sys/class/graphics/fb0/modes \
            /sys/class/graphics/fb0/blank \
            /sys/class/leds/lcd-backlight/brightness \
            /sys/class/leds/lcd-backlight/max_brightness; do
            echo "--- $F ---"
            cat "$F" 2>&1
        done
    '
    capture_sh "$D/surfaceflinger.txt" 'dumpsys SurfaceFlinger'
    capture_sh "$D/display.txt" 'dumpsys display'
    capture_sh "$D/window.txt" 'dumpsys window'
}

snapshot_power_thermal()
{
    D="$1/power_thermal"
    mkdir -p "$D"

    capture_sh "$D/cpu.txt" '
        cat /sys/devices/system/cpu/possible 2>/dev/null
        cat /sys/devices/system/cpu/present 2>/dev/null
        cat /sys/devices/system/cpu/online 2>/dev/null
        echo
        for CPU in /sys/devices/system/cpu/cpu[0-9]*; do
            [ -d "$CPU/cpufreq" ] || continue
            echo "--- $CPU ---"
            for F in scaling_cur_freq scaling_min_freq scaling_max_freq scaling_governor cpuinfo_min_freq cpuinfo_max_freq; do
                echo -n "$F="
                cat "$CPU/cpufreq/$F" 2>/dev/null
            done
        done
    '
    capture_sh "$D/thermal.txt" '
        for Z in /sys/class/thermal/thermal_zone*; do
            [ -e "$Z" ] || continue
            echo "--- $Z ---"
            echo -n "type="; cat "$Z/type" 2>/dev/null
            echo -n "temp="; cat "$Z/temp" 2>/dev/null
        done
        echo
        dumpsys thermalservice 2>&1
    '
    capture_sh "$D/power.txt" 'dumpsys power'
    capture_sh "$D/battery.txt" 'dumpsys battery; dumpsys batterystats 2>&1'
    capture_sh "$D/wakeup_suspend.txt" '
        cat /sys/kernel/debug/wakeup_sources 2>&1
        echo
        cat /sys/kernel/debug/suspend_stats 2>&1
    '
}

snapshot_security()
{
    D="$1/security"
    mkdir -p "$D"

    capture_sh "$D/selinux.txt" '
        getenforce 2>&1
        echo
        cat /sys/fs/selinux/enforce 2>&1
        echo
        cat /proc/self/attr/current 2>&1
        echo
        ls -ldZ \
            /data /data/misc /data/misc/camera \
            /data/vendor /data/vendor/misc /data/vendor/misc/audio \
            /dev/qseecom /dev/ion /dev/snd /dev/video0 \
            2>&1
    '
    capture_sh "$D/binder_debug.txt" '
        for F in \
            /sys/kernel/debug/binder/state \
            /sys/kernel/debug/binder/stats \
            /sys/kernel/debug/binder/transactions \
            /sys/kernel/debug/binder/failed_transaction_log; do
            echo "--- $F ---"
            cat "$F" 2>&1
        done
    '
}

snapshot_packages_activity()
{
    D="$1/framework"
    mkdir -p "$D"

    capture_sh "$D/packages.txt" 'pm list packages -f -U 2>&1'
    capture_sh "$D/activity_processes.txt" 'dumpsys activity processes'
    capture_sh "$D/activity_services.txt" 'dumpsys activity services'
    capture_sh "$D/activity_top.txt" 'dumpsys activity top 2>&1; dumpsys activity activities 2>&1'
    capture_sh "$D/jobs_alarms.txt" 'dumpsys jobscheduler 2>&1; dumpsys alarm 2>&1'
    capture_sh "$D/deviceidle.txt" 'dumpsys deviceidle 2>&1'
}

snapshot_all()
{
    PREFIX="$1"
    ROOT="$LOGDIR/$PREFIX"
    mkdir -p "$ROOT"

    snapshot_general "$ROOT"
    snapshot_fde_qsee "$ROOT"
    snapshot_storage "$ROOT"
    snapshot_audio "$ROOT"
    snapshot_camera "$ROOT"
    snapshot_media "$ROOT"
    snapshot_sensors_input "$ROOT"
    snapshot_bluetooth "$ROOT"
    snapshot_radio "$ROOT"
    snapshot_wifi_network_gps "$ROOT"
    snapshot_usb "$ROOT"
    snapshot_display "$ROOT"
    snapshot_power_thermal "$ROOT"
    snapshot_security "$ROOT"
    snapshot_packages_activity "$ROOT"
}

copy_small_file()
{
    SRC="$1"
    DESTROOT="$2"

    [ -f "$SRC" ] || return
    SIZE=$(wc -c < "$SRC" 2>/dev/null)
    [ -n "$SIZE" ] || return
    [ "$SIZE" -le "$MAX_CONFIG_BYTES" ] || return

    DEST="$DESTROOT$SRC"
    mkdir -p "$(dirname "$DEST")"
    cp -p "$SRC" "$DEST" 2>/dev/null
}

copy_configs()
{
    DEST="$LOGDIR/06_configs"
    mkdir -p "$DEST"

    for FILE in \
        /system/etc/fstab* \
        /vendor/etc/fstab* \
        /system/etc/audio*.conf \
        /system/etc/audio*.xml \
        /system/etc/mixer*.xml \
        /vendor/etc/audio*.conf \
        /vendor/etc/audio*.xml \
        /vendor/etc/mixer*.xml \
        /system/etc/media*.xml \
        /vendor/etc/media*.xml \
        /vendor/etc/gpfspath*.xml \
        /vendor/etc/permissions/*.xml; do
        [ -f "$FILE" ] || continue
        copy_small_file "$FILE" "$DEST"
    done

    for ROOT in \
        /system/etc/init \
        /vendor/etc/init \
        /system/etc/camera \
        /vendor/etc/camera; do
        [ -d "$ROOT" ] || continue
        find "$ROOT" -type f 2>/dev/null | while read FILE; do
            copy_small_file "$FILE" "$DEST"
        done
    done

    capture_sh "$DEST/relevant_init_rules.txt" '
        grep -RniE \
            "vold.decrypt|post-fs-data|camera|audio|qsee|keymaster|sensor|bluetooth|gnss|rild" \
            /init*.rc /system/etc/init /vendor/etc/init 2>/dev/null
    '

    capture_sh "$DEST/relevant_files_listing.txt" '
        find /system /vendor -maxdepth 5 -type f 2>/dev/null | \
            grep -iE "camera|audio|mixer|acdb|keymaster|qsee|sensor|bluetooth|gnss" | \
            sort
    '
}

copy_recent_crashes()
{
    DEST="$LOGDIR/05_crashes/files"
    mkdir -p "$DEST"

    COUNT=0
    for FILE in $(ls -1t \
        /data/tombstones/tombstone_* \
        /data/vendor/tombstones/tombstone_* \
        /data/anr/* \
        /data/system/dropbox/* \
        2>/dev/null); do
        [ -f "$FILE" ] || continue
        NAME=$(echo "$FILE" | sed 's#/#_#g' | sed 's/^_//')
        tail -c "$MAX_CRASH_BYTES" "$FILE" > "$DEST/$NAME" 2>/dev/null
        COUNT=$((COUNT + 1))
        [ "$COUNT" -ge "$MAX_CRASH_FILES" ] && break
    done

    capture_sh "$LOGDIR/05_crashes/listings.txt" '
        ls -laZ /data/tombstones /data/vendor/tombstones /data/anr /data/system/dropbox 2>&1
    '
    capture_sh "$LOGDIR/05_crashes/dropbox.txt" '
        dumpsys dropbox --print 2>&1 | tail -c 5242880
    '
}

make_filtered_logs()
{
    FDIR="$LOGDIR/07_filtered"
    mkdir -p "$FDIR"

    SOURCES=""
    for FILE in         "$LOGDIR/01_boot/logcat_boot_all.txt"         "$LOGDIR/01_boot/dmesg_early.txt"         "$LOGDIR/03_live/logcat_live_all.txt"         "$LOGDIR/03_live"/logcat_live_all.txt.*         "$LOGDIR/03_live/dmesg_latest.txt"         "$LOGDIR/04_latest/dmesg_latest.txt"         "$LOGDIR/04_final/dmesg_final.txt"
    do
        [ -f "$FILE" ] || continue
        SOURCES="$SOURCES $FILE"
    done

    grep -iE \
        "cryptfs|dm-crypt|vold|vold.decrypt|decrypt|encrypt|keymaster|keystore|qsee|rpmb|listener|post-fs-data|trigger_restart_framework|tmpfs.*data|mount.*data" \
        $SOURCES > "$FDIR/fde_qsee.txt" 2>&1

    grep -iE \
        "audio|audioserver|audioflinger|audiopolicy|tinyalsa|tinymix|acdb|voice|soundtrigger|snd_device|pcm|mixer" \
        $SOURCES > "$FDIR/audio.txt" 2>&1

    grep -iE \
        "camera|cameraserver|camera.provider|mm-qcamera|snap|jpeg|jpege|camss|vfe|cpp|media.camera|DCIM" \
        $SOURCES > "$FDIR/camera.txt" 2>&1

    grep -iE \
        "sensor|sensorservice|sensors-hal|inputflinger|iio|proximity|accelerometer|gyroscope" \
        $SOURCES > "$FDIR/sensors.txt" 2>&1

    grep -iE \
        "bluetooth|btif|a2dp|avrcp|headset|hfp|sco|hci" \
        $SOURCES > "$FDIR/bluetooth.txt" 2>&1

    grep -iE \
        "rild|RILJ|qcril|radio|telephony|ims|ServiceState|DataConnection|Subscription|SIM" \
        $SOURCES > "$FDIR/radio.txt" 2>&1

    grep -iE \
        "wifi|wlan|wcnss|cnss|wpa_supplicant|hostapd|gnss|gps|izat|location" \
        $SOURCES > "$FDIR/wifi_gps.txt" 2>&1

    grep -iE \
        "usb|adbd|mtp|ptp|android_usb|configfs|functionfs|ffs" \
        $SOURCES > "$FDIR/usb.txt" 2>&1

    grep -iE \
        "surfaceflinger|composer|hwc|gralloc|display|mdss|backlight|brightness" \
        $SOURCES > "$FDIR/display.txt" 2>&1

    grep -iE \
        "avc:.*denied|selinux.*denied" \
        $SOURCES > "$FDIR/selinux.txt" 2>&1

    grep -iE \
        "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGBUS|SIGABRT|ANR in|am_anr|tombstone|crash_dump|Abort message|backtrace:" \
        $SOURCES > "$FDIR/crashes.txt" 2>&1

    grep -iE \
        "error|failed|failure|fatal|abort|denied|timeout|timed out|not found|No such file|cannot|unable|died|restarting" \
        $SOURCES > "$FDIR/all_errors.txt" 2>&1
}

save_early_state()
{
    E="$LOGDIR/00_early_after_decrypt"
    mkdir -p "$E"

    capture_sh "$E/status.txt" '
        date
        echo "sys.boot_completed=$(getprop sys.boot_completed)"
        echo "dev.bootcomplete=$(getprop dev.bootcomplete)"
        echo "vold.decrypt=$(getprop vold.decrypt)"
        echo "ro.crypto.state=$(getprop ro.crypto.state)"
        echo "crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
        echo "data_mount=$(grep " /data " /proc/mounts)"
        getprop | grep "init.svc" | sort
    '
    capture_sh "$E/processes.txt" 'ps -AZ 2>/dev/null; ps -A'
    capture_sh "$E/mounts.txt" 'cat /proc/mounts; df -h 2>/dev/null'
    capture_sh "$E/critical_paths.txt" '
        ls -ldZ /data /data/misc/camera /data/vendor/misc/audio /data/media/0 2>&1
        echo "camera_target=$(readlink -f /data/misc/camera 2>/dev/null)"
    '

    dmesg > "$LOGDIR/01_boot/dmesg_early.txt" 2>&1
    logcat -b all -v threadtime -d > "$LOGDIR/01_boot/logcat_boot_all.txt" 2>&1
    logcat -b crash -v threadtime -d > "$LOGDIR/01_boot/logcat_boot_crash.txt" 2>&1
    logcat -b radio -v threadtime -d > "$LOGDIR/01_boot/logcat_boot_radio.txt" 2>&1
    logcat -b events -v threadtime -d > "$LOGDIR/01_boot/logcat_boot_events.txt" 2>&1
    logcat -L -b all -v threadtime -d > "$LOGDIR/01_boot/logcat_previous_boot.txt" 2>&1
}

write_timeline_entry()
{
    {
        section "TIMELINE"
        echo "elapsed=${ELAPSED}s"
        date

        echo
        echo "--- BOOT / FDE ---"
        echo "sys.boot_completed=$(getprop sys.boot_completed)"
        echo "dev.bootcomplete=$(getprop dev.bootcomplete)"
        echo "vold.decrypt=$(getprop vold.decrypt)"
        echo "crypto_state=$(getprop ro.crypto.state)"
        echo "crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
        grep " /data " /proc/mounts

        echo
        echo "--- CRITICAL SERVICE PROPERTIES ---"
        getprop | grep -iE \
            "init.svc.*(vold|qsee|keymaster|audio|camera|media|sensor|bluetooth|rild|radio|gnss|surfaceflinger|composer|adbd)" | sort

        echo
        echo "--- CRITICAL PROCESSES ---"
        ps -A | grep -iE \
            "vold|qsee|keymaster|audio|camera|media|sensor|bluetooth|rild|radio|gnss|surfaceflinger|composer|adbd"

        echo
        echo "--- DATA PATHS ---"
        ls -ldZ \
            /data/misc/camera \
            /data/vendor/misc/audio \
            /data/vendor/misc/audio/acdbdata \
            /data/media/0 \
            2>&1
        echo "camera_target=$(readlink -f /data/misc/camera 2>/dev/null)"

        echo
        echo "--- USB ---"
        echo "config=$(getprop sys.usb.config)"
        echo "state=$(getprop sys.usb.state)"
        echo "functions=$(cat /sys/class/android_usb/android0/functions 2>/dev/null)"
        echo "enable=$(cat /sys/class/android_usb/android0/enable 2>/dev/null)"

        echo
        echo "--- RECENT CAMERA FILES ---"
        find /data/media/0/DCIM/Camera /storage/emulated/0/DCIM/Camera \
            -maxdepth 1 -type f -mmin -20 -ls 2>/dev/null

        echo
        echo "--- RESOURCES ---"
        df -h /data 2>/dev/null
        grep -E "MemTotal|MemFree|MemAvailable|Slab" /proc/meminfo

        echo
        echo "--- NEW CRASH FILES ---"
        ls -1t /data/tombstones/tombstone_* /data/anr/* 2>/dev/null | head -n 10
    } >> "$LOGDIR/03_live/timeline.txt" 2>&1
}



save_quick_state()
{
    D="$LOGDIR/04_latest"
    mkdir -p "$D"

    date > "$D/date.txt" 2>&1
    getprop > "$D/getprop_latest.txt" 2>&1
    dmesg > "$D/dmesg_latest.txt" 2>&1
    ps -AZ > "$D/processes_latest.txt" 2>&1
    cat /proc/mounts > "$D/mounts_latest.txt" 2>&1

    logcat -b crash -v threadtime -d \
        > "$D/logcat_crash_latest.txt" 2>&1
    logcat -b radio -v threadtime -d \
        > "$D/logcat_radio_latest.txt" 2>&1
    logcat -b events -v threadtime -d \
        > "$D/logcat_events_latest.txt" 2>&1

    {
        echo "date=$(date)"
        echo "sys.boot_completed=$(getprop sys.boot_completed)"
        echo "dev.bootcomplete=$(getprop dev.bootcomplete)"
        echo "vold.decrypt=$(getprop vold.decrypt)"
        echo "ro.crypto.state=$(getprop ro.crypto.state)"
        echo "crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
        echo
        getprop | grep -iE \
            "init\.svc.*(vold|qsee|keymaster|audio|camera|media|sensor|bluetooth|rild|radio|gnss|surfaceflinger|composer|adbd)" |
            sort
    } > "$D/critical_state_latest.txt" 2>&1

    copy_recent_crashes
    make_filtered_logs
    sync
}

save_full_latest()
{
    rm -rf "$LOGDIR/04_full_latest"
    snapshot_all "04_full_latest"
    copy_recent_crashes
    make_filtered_logs

    {
        echo "full_snapshot=$(date)"
        echo "elapsed_seconds=$ELAPSED"
    } >> "$LOGDIR/status.txt" 2>&1

    sync
}

finalize_logs()
{
    [ "$FINALIZED" = "1" ] && return
    FINALIZED=1

    F="$LOGDIR/04_final"
    mkdir -p "$F"

    {
        echo "shutdown_capture=$(date)"
        echo "elapsed_seconds=$ELAPSED"
        echo "reason=$1"
        echo "sys.boot_completed=$(getprop sys.boot_completed)"
        echo "vold.decrypt=$(getprop vold.decrypt)"
        echo "crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
    } > "$F/status_final.txt" 2>&1

    getprop > "$F/getprop_final.txt" 2>&1
    ps -AZ > "$F/processes_final.txt" 2>&1
    cat /proc/mounts > "$F/mounts_final.txt" 2>&1
    dmesg > "$F/dmesg_final.txt" 2>&1
    logcat -b crash -v threadtime -d > "$F/logcat_crash_final.txt" 2>&1
    logcat -b radio -v threadtime -d > "$F/logcat_radio_final.txt" 2>&1
    logcat -b events -v threadtime -d > "$F/logcat_events_final.txt" 2>&1

    copy_recent_crashes
    make_filtered_logs

    find "$LOGDIR" -type f -exec chmod 0644 {} \; 2>/dev/null
    find "$LOGDIR" -type d -exec chmod 0755 {} \; 2>/dev/null
    sync
}


start_live_logs()
{
    LIVE_DIR="$LOGDIR/03_live"
    mkdir -p "$LIVE_DIR"

    # Prefer logcat's built-in rotation. This keeps collecting indefinitely
    # without allowing one text file to consume the whole userdata partition.
    if logcat --help 2>&1 | grep -q -- "-r"; then
        logcat \
            -b all \
            -v threadtime \
            -f "$LIVE_DIR/logcat_live_all.txt" \
            -r "$LOGCAT_ROTATE_KB" \
            -n "$LOGCAT_ROTATE_COUNT" \
            >/dev/null 2>&1 &
        LOGCAT_PID=$!
        echo "logcat_mode=rotating" >> "$LOGDIR/status.txt"
    else
        logcat -b all -v threadtime \
            > "$LIVE_DIR/logcat_live_all.txt" 2>&1 &
        LOGCAT_PID=$!
        echo "logcat_mode=plain_unlimited" >> "$LOGDIR/status.txt"
    fi

    echo "logcat_pid=$LOGCAT_PID" >> "$LOGDIR/status.txt"

    # Some Android toolbox/toybox builds support dmesg -w. Use it only when
    # available. We deliberately do not read /proc/kmsg because stealing the
    # kernel log reader can disturb other components.
    if dmesg --help 2>&1 | grep -q -- "-w"; then
        dmesg -w > "$LIVE_DIR/kernel_live.txt" 2>&1 &
        KERNEL_LOG_PID=$!
        echo "kernel_live_mode=dmesg-w" >> "$LOGDIR/status.txt"
        echo "kernel_log_pid=$KERNEL_LOG_PID" >> "$LOGDIR/status.txt"
    else
        echo "kernel_live_mode=final-dmesg-snapshot-only" >> "$LOGDIR/status.txt"
    fi
}

trap cleanup EXIT
trap 'finalize_logs TERM; exit 0' TERM
trap 'finalize_logs INT; exit 0' INT
trap 'finalize_logs HUP; exit 0' HUP

acquire_lock

# Preserve the last completed or interrupted boot instead of deleting it.
rm -rf "$PREV_LOGDIR"
if [ -d "$LOGDIR" ]; then
    mv "$LOGDIR" "$PREV_LOGDIR" 2>/dev/null
fi

mkdir -p \
    "$LOGDIR/00_early_after_decrypt" \
    "$LOGDIR/01_boot" \
    "$LOGDIR/02_after_boot" \
    "$LOGDIR/03_live" \
    "$LOGDIR/04_latest" \
    "$LOGDIR/04_full_latest" \
    "$LOGDIR/04_final" \
    "$LOGDIR/05_crashes" \
    "$LOGDIR/06_configs" \
    "$LOGDIR/07_filtered"
chmod 0775 "$LOGDIR"

FINALIZED=0
ELAPSED=0
BOOT_SNAPSHOT_DONE=0
LAST_QUICK=0
LAST_FULL=0

kmsg "continuous collector started pid=$$"

{
    echo "script_started=$(date)"
    echo "pid=$$"
    echo "mode=automatic_continuous"
    echo "output_directory=$LOGDIR"
    echo "previous_directory=$PREV_LOGDIR"
    echo "timeline_interval=$TIMELINE_INTERVAL"
    echo "quick_snapshot_interval=$QUICK_SNAPSHOT_INTERVAL"
    echo "full_snapshot_interval=$FULL_SNAPSHOT_INTERVAL"
    echo "logcat_rotate_kb=$LOGCAT_ROTATE_KB"
    echo "logcat_rotate_count=$LOGCAT_ROTATE_COUNT"
    echo "initial_sys.boot_completed=$(getprop sys.boot_completed)"
    echo "initial_dev.bootcomplete=$(getprop dev.bootcomplete)"
    echo "initial_vold.decrypt=$(getprop vold.decrypt)"
    echo "initial_crypto_state=$(getprop ro.crypto.state)"
    echo "initial_crypto_blkdev=$(getprop ro.crypto.fs_crypto_blkdev)"
} > "$LOGDIR/status.txt" 2>&1

# Continuous logcat starts first. Everything that follows can be slow without
# creating a blind spot in the live Android logs.
start_live_logs

save_early_state
save_pstore
copy_configs
save_quick_state

while :; do
    write_timeline_entry

    if [ "$BOOT_SNAPSHOT_DONE" -eq 0 ] &&
       [ "$(getprop sys.boot_completed)" = "1" ]; then
        snapshot_all "02_after_boot"
        BOOT_SNAPSHOT_DONE=1
        echo "after_boot_snapshot=$(date)" >> "$LOGDIR/status.txt"
        sync
    fi

    if [ $((ELAPSED - LAST_QUICK)) -ge "$QUICK_SNAPSHOT_INTERVAL" ]; then
        save_quick_state
        LAST_QUICK=$ELAPSED
    fi

    if [ $((ELAPSED - LAST_FULL)) -ge "$FULL_SNAPSHOT_INTERVAL" ]; then
        save_full_latest
        LAST_FULL=$ELAPSED
    fi

    sleep "$TIMELINE_INTERVAL"
    ELAPSED=$((ELAPSED + TIMELINE_INTERVAL))
done
