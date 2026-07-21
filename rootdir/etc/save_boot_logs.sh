#!/system/bin/sh
#
# j2y18lte universal boot/test log collector
#
# Output:
#   /data/local/tmp/log/
#
# The collector starts after Android boot, records a live logcat window,
# snapshots important subsystems before and after the test, and leaves
# all files unpacked for copying through recovery.
#

BASE="/data/local/tmp"
LOGDIR="$BASE/log"
MAX_BOOT_WAIT=300
POST_BOOT_DELAY=10
LIVE_SECONDS=600
TIMELINE_INTERVAL=10

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

read_file()
{
    FILE="$1"
    LABEL="$2"

    echo "--- $LABEL: $FILE ---"
    if [ -e "$FILE" ]; then
        cat "$FILE" 2>&1
    else
        echo "MISSING"
    fi
}

save_pstore()
{
    if [ -f /proc/last_kmsg ]; then
        cat /proc/last_kmsg > "$LOGDIR/last_kmsg.txt" 2>&1
    else
        echo "MISSING /proc/last_kmsg" > "$LOGDIR/last_kmsg.txt"
    fi

    if ls /sys/fs/pstore/console-ramoops* >/dev/null 2>&1; then
        cat /sys/fs/pstore/console-ramoops* \
            > "$LOGDIR/console-ramoops.txt" 2>&1
    else
        echo "MISSING console-ramoops" \
            > "$LOGDIR/console-ramoops.txt"
    fi

    if ls /sys/fs/pstore/pmsg-ramoops* >/dev/null 2>&1; then
        cat /sys/fs/pstore/pmsg-ramoops* \
            > "$LOGDIR/pmsg-ramoops.txt" 2>&1
    else
        echo "MISSING pmsg-ramoops" \
            > "$LOGDIR/pmsg-ramoops.txt"
    fi
}

save_storage_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "MOUNTS"
        cat /proc/mounts

        section "VOLD"
        dumpsys mount
        echo
        dumpsys vold 2>/dev/null

        section "STORAGE DIRECTORIES"
        ls -ldZ \
            /data \
            /data/media \
            /data/media/0 \
            /data/media/0/DCIM \
            /data/media/0/DCIM/Camera \
            /storage \
            /storage/emulated \
            /storage/emulated/0 \
            /storage/emulated/0/DCIM \
            /storage/emulated/0/DCIM/Camera \
            2>&1

        section "DCIM THROUGH /data/media"
        ls -laZ /data/media/0/DCIM/Camera 2>&1

        section "DCIM THROUGH EMULATED STORAGE"
        ls -laZ /storage/emulated/0/DCIM/Camera 2>&1

        section "RECENT DCIM FILES"
        find \
            /data/media/0/DCIM \
            /storage/emulated/0/DCIM \
            -type f -mmin -30 -ls 2>/dev/null

        section "MEDIASTORE CAMERA ROWS"
        content query \
            --uri content://media/external/images/media \
            --projection _id:_data:_display_name:mime_type:date_added \
            --sort "date_added DESC" 2>&1 | head -n 100
    } > "$LOGDIR/${PREFIX}_storage.txt" 2>&1
}

save_camera_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "PROCESSES"
        ps -A | grep -iE \
            "camera|snap|media|jpeg|provider" 2>/dev/null

        section "INIT SERVICES"
        getprop | grep -iE \
            "init\.svc.*(camera|media|jpeg)" 2>/dev/null

        section "CAMERA PROPERTIES"
        getprop | grep -iE \
            "camera|jpeg|media" 2>/dev/null

        section "CAMERA DEVICE NODES"
        ls -laZ \
            /dev/media* \
            /dev/video* \
            /dev/v4l-subdev* \
            /dev/msm_camera* \
            2>&1

        section "VIDEO4LINUX SYSFS"
        for NODE in /sys/class/video4linux/*; do
            [ -e "$NODE" ] || continue
            echo "--- $NODE ---"
            cat "$NODE/name" 2>/dev/null
            readlink -f "$NODE/device" 2>/dev/null
        done
    } > "$LOGDIR/${PREFIX}_camera_state.txt" 2>&1

    dumpsys media.camera \
        > "$LOGDIR/${PREFIX}_media_camera.txt" 2>&1

    dumpsys package org.lineageos.snap \
        > "$LOGDIR/${PREFIX}_snap_package.txt" 2>&1
}

save_bluetooth_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "BLUETOOTH PROPERTIES"
        getprop | grep -iE \
            "bluetooth|bt\.|persist\.vendor\.bt" 2>/dev/null

        section "BLUETOOTH PROCESSES"
        ps -A | grep -iE \
            "bluetooth|bt_logger|hci|wcnss" 2>/dev/null

        section "BLUETOOTH SERVICES"
        service list | grep -i bluetooth 2>/dev/null
    } > "$LOGDIR/${PREFIX}_bluetooth_state.txt" 2>&1

    dumpsys bluetooth_manager \
        > "$LOGDIR/${PREFIX}_bluetooth_manager.txt" 2>&1

    dumpsys bluetooth_a2dp \
        > "$LOGDIR/${PREFIX}_bluetooth_a2dp.txt" 2>&1

    dumpsys bluetooth_headset \
        > "$LOGDIR/${PREFIX}_bluetooth_headset.txt" 2>&1
}

save_radio_call_audio_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "RADIO PROPERTIES"
        getprop | grep -iE \
            "gsm\.|ril\.|radio\.|telephony|operator|baseband" 2>/dev/null

        section "RIL PROCESSES"
        ps -A | grep -iE \
            "rild|ims|qcril|radio|netmgr|ipacm|qti" 2>/dev/null

        section "AUDIO PROCESSES"
        ps -A | grep -iE \
            "audioserver|audio|acdb|voice" 2>/dev/null

        section "AUDIO SYSFS / DEVICES"
        ls -laZ /dev/snd 2>&1
    } > "$LOGDIR/${PREFIX}_radio_audio_state.txt" 2>&1

    dumpsys telephony.registry \
        > "$LOGDIR/${PREFIX}_telephony_registry.txt" 2>&1

    dumpsys telecom \
        > "$LOGDIR/${PREFIX}_telecom.txt" 2>&1

    dumpsys isub \
        > "$LOGDIR/${PREFIX}_subscriptions.txt" 2>&1

    dumpsys iphonesubinfo \
        > "$LOGDIR/${PREFIX}_phone_info.txt" 2>&1

    {
        section "TELEPHONY BINDER SERVICES"
        service list | grep -iE \
            "phone|isub|iphonesubinfo|telephony|carrier" 2>/dev/null

        section "SIMINFO DATABASE"
        content query \
            --uri content://telephony/siminfo 2>&1

        section "DEFAULT SUBSCRIPTIONS"
        echo "multi_sim_voice_call=$(settings get global multi_sim_voice_call)"
        echo "multi_sim_sms=$(settings get global multi_sim_sms)"
        echo "multi_sim_data_call=$(settings get global multi_sim_data_call)"
        echo "default_voice_sub=$(settings get global multi_sim_voice_call)"
        echo "default_sms_sub=$(settings get global multi_sim_sms)"
        echo "default_data_sub=$(settings get global multi_sim_data_call)"

        section "PACKAGE UIDS"
        pm list packages -U | grep -E \
            "com.android.systemui|com.android.settings$|com.android.phone"

        section "SYSTEMUI PACKAGE"
        dumpsys package com.android.systemui

        section "SETTINGS PACKAGE"
        dumpsys package com.android.settings

        section "PHONE PACKAGE"
        dumpsys package com.android.phone
    } > "$LOGDIR/${PREFIX}_telephony_packages.txt" 2>&1

    dumpsys audio \
        > "$LOGDIR/${PREFIX}_audio.txt" 2>&1

    dumpsys media.audio_flinger \
        > "$LOGDIR/${PREFIX}_audio_flinger.txt" 2>&1

    dumpsys media.audio_policy \
        > "$LOGDIR/${PREFIX}_audio_policy.txt" 2>&1
}

save_usb_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "USB PROPERTIES"
        getprop | grep -iE \
            "usb|adb" 2>/dev/null

        section "USB SERVICE STATE"
        getprop init.svc.adbd
        getprop sys.usb.config
        getprop sys.usb.state
        getprop persist.sys.usb.config
        getprop sys.usb.configfs
        getprop sys.usb.controller

        section "LEGACY GADGET"
        ls -laZ /sys/class/android_usb/android0 2>&1
        for NODE in \
            enable \
            idVendor \
            idProduct \
            functions \
            state
        do
            read_file \
                "/sys/class/android_usb/android0/$NODE" \
                "$NODE"
        done

        section "USB DEVICES"
        cat /proc/bus/input/devices 2>/dev/null
    } > "$LOGDIR/${PREFIX}_usb_state.txt" 2>&1

    dumpsys usb \
        > "$LOGDIR/${PREFIX}_usb_dump.txt" 2>&1
}

save_power_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "CPU TOPOLOGY"
        read_file /sys/devices/system/cpu/possible possible
        read_file /sys/devices/system/cpu/present present
        read_file /sys/devices/system/cpu/online online

        section "CPU FREQUENCIES"
        read_file \
            /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies \
            scaling_available_frequencies
        read_file \
            /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq \
            cpuinfo_min_freq
        read_file \
            /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq \
            cpuinfo_max_freq
        read_file \
            /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq \
            scaling_cur_freq
        read_file \
            /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor \
            scaling_governor

        section "WAKEUP SOURCES"
        cat /sys/kernel/debug/wakeup_sources 2>/dev/null

        section "SUSPEND STATS"
        cat /sys/kernel/debug/suspend_stats 2>/dev/null
    } > "$LOGDIR/${PREFIX}_power_state.txt" 2>&1

    dumpsys power \
        > "$LOGDIR/${PREFIX}_power.txt" 2>&1

    dumpsys batterystats \
        > "$LOGDIR/${PREFIX}_batterystats.txt" 2>&1

    dumpsys battery \
        > "$LOGDIR/${PREFIX}_battery.txt" 2>&1
}

save_display_sensor_state()
{
    PREFIX="$1"

    {
        section "DATE"
        date

        section "DISPLAY NODES"
        read_file /sys/class/graphics/fb0/name fb0_name
        read_file /sys/class/graphics/fb0/modes fb0_modes
        read_file /sys/class/graphics/fb0/blank fb0_blank
        read_file \
            /sys/class/leds/lcd-backlight/brightness \
            brightness
        read_file \
            /sys/class/leds/lcd-backlight/max_brightness \
            max_brightness

        section "DISPLAY SERVICES"
        getprop | grep -iE \
            "init\.svc.*(surfaceflinger|composer|hwc|gralloc|light)" \
            2>/dev/null
    } > "$LOGDIR/${PREFIX}_display_state.txt" 2>&1

    dumpsys SurfaceFlinger \
        > "$LOGDIR/${PREFIX}_surfaceflinger.txt" 2>&1

    dumpsys sensorservice \
        > "$LOGDIR/${PREFIX}_sensors.txt" 2>&1
}

copy_tombstones()
{
    mkdir -p "$LOGDIR/tombstones"

    COUNT=0
    for FILE in $(ls -1t /data/tombstones/tombstone_* 2>/dev/null); do
        [ -f "$FILE" ] || continue
        cp "$FILE" "$LOGDIR/tombstones/" 2>/dev/null
        COUNT=$((COUNT + 1))
        [ "$COUNT" -ge 10 ] && break
    done

    ls -laZ /data/tombstones \
        > "$LOGDIR/tombstones_listing.txt" 2>&1
}

make_filtered_logs()
{
    grep -iE \
        "camera|snap|takePicture|take_picture|snapshot|capture|jpeg|jpege|qomx|exif|MediaSave|MediaProvider|MediaStore|DCIM|Failed to write|saveImage|store JPEG" \
        "$LOGDIR/logcat_boot.txt" "$LOGDIR/logcat_live.txt" \
        > "$LOGDIR/filtered_camera.txt" 2>&1

    grep -iE \
        "bluetooth|btif|btm_|bta_|a2dp|avdt|avrcp|headset|hfp|sco|aptx|ldac|SIGBUS|libbluetooth" \
        "$LOGDIR/logcat_boot.txt" "$LOGDIR/logcat_live.txt" \
        > "$LOGDIR/filtered_bluetooth.txt" 2>&1

    grep -iE \
        "RIL|RILJ|rild|radio|ServiceState|DataConnection|GsmCdma|Subscription|subId|TelephonyRegistry|PhoneSubInfo|DEVICE_IDENTITY|IMEI|READ_PHONE_STATE|READ_PRIVILEGED_PHONE_STATE|Permission Denial|KeyguardUpdateMonitor|CarrierText|No service|Telecom|InCall|voice_start|voice_stop|voicemmode|ACDB|audio_route|snd_device|bt-sco" \
        "$LOGDIR/logcat_boot.txt" "$LOGDIR/logcat_live.txt" \
        > "$LOGDIR/filtered_radio_calls_audio.txt" 2>&1

    grep -iE \
        "UsbDeviceManager|UsbHandler|sys\.usb|persist\.sys\.usb|adbd|mtp|ptp|android_usb|functionfs|USB disconnect|waitForState" \
        "$LOGDIR/logcat_boot.txt" "$LOGDIR/logcat_live.txt" \
        > "$LOGDIR/filtered_usb.txt" 2>&1

    grep -iE \
        "FATAL EXCEPTION|Fatal signal|SIGSEGV|SIGBUS|SIGABRT|ANR in|am_anr|tombstone|crash_dump|DEBUG.*pid|backtrace:|Abort message" \
        "$LOGDIR/logcat_boot.txt" "$LOGDIR/logcat_live.txt" \
        > "$LOGDIR/filtered_crashes.txt" 2>&1

    {
        grep -iE \
            "avc:.*denied|selinux.*denied" \
            "$LOGDIR/dmesg_before.txt" \
            "$LOGDIR/dmesg_after.txt" \
            "$LOGDIR/logcat_boot.txt" \
            "$LOGDIR/logcat_live.txt" 2>/dev/null
    } > "$LOGDIR/filtered_selinux.txt" 2>&1

    grep -iE \
        "camera|camss|msm[_-]camera|jpeg|jpege|qomx|vfe|cpp|bluetooth|hci|wcnss|rild|radio|audio|acdb|usb|android_usb|suspend|resume|avc:.*denied|error|fail|fatal" \
        "$LOGDIR/dmesg_after.txt" \
        > "$LOGDIR/filtered_dmesg.txt" 2>&1
}

snapshot_all()
{
    PREFIX="$1"

    save_storage_state "$PREFIX"
    save_camera_state "$PREFIX"
    save_bluetooth_state "$PREFIX"
    save_radio_call_audio_state "$PREFIX"
    save_usb_state "$PREFIX"
    save_power_state "$PREFIX"
    save_display_sensor_state "$PREFIX"
}

kmsg "started"

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"
chmod 0775 "$LOGDIR"

{
    echo "script_started=$(date)"
    echo "max_boot_wait=$MAX_BOOT_WAIT"
    echo "post_boot_delay=$POST_BOOT_DELAY"
    echo "live_seconds=$LIVE_SECONDS"
    echo "timeline_interval=$TIMELINE_INTERVAL"
    echo "initial_sys.boot_completed=$(getprop sys.boot_completed)"
    echo "initial_dev.bootcomplete=$(getprop dev.bootcomplete)"
} > "$LOGDIR/status.txt" 2>&1

WAITED=0
while [ "$(getprop sys.boot_completed)" != "1" ] &&
      [ "$WAITED" -lt "$MAX_BOOT_WAIT" ]; do
    sleep 2
    WAITED=$((WAITED + 2))
done

sleep "$POST_BOOT_DELAY"

{
    echo "capture_started=$(date)"
    echo "waited_for_boot_seconds=$WAITED"
    echo "sys.boot_completed=$(getprop sys.boot_completed)"
    echo "dev.bootcomplete=$(getprop dev.bootcomplete)"
    echo "bootanim=$(getprop init.svc.bootanim)"
    echo "selinux=$(getenforce 2>/dev/null)"
    echo "fingerprint=$(getprop ro.build.fingerprint)"
    echo "kernel=$(uname -a)"
} >> "$LOGDIR/status.txt" 2>&1

getprop > "$LOGDIR/getprop.txt" 2>&1
dmesg > "$LOGDIR/dmesg_before.txt" 2>&1
logcat -b all -v threadtime -d \
    > "$LOGDIR/logcat_boot.txt" 2>&1

save_pstore
snapshot_all "before"

logcat -b all -v threadtime \
    > "$LOGDIR/logcat_live.txt" 2>&1 &
LOGCAT_PID=$!

ELAPSED=0
while [ "$ELAPSED" -lt "$LIVE_SECONDS" ]; do
    {
        section "TIMELINE"
        echo "elapsed=${ELAPSED}s"
        date

        echo
        echo "--- IMPORTANT PROCESSES ---"
        ps -A | grep -iE \
            "camera|snap|media|bluetooth|rild|radio|audio|adbd" \
            2>/dev/null

        echo
        echo "--- USB ---"
        echo "config=$(getprop sys.usb.config)"
        echo "state=$(getprop sys.usb.state)"
        echo "adbd=$(getprop init.svc.adbd)"

        echo
        echo "--- RADIO ---"
        echo "operator=$(getprop gsm.operator.alpha)"
        echo "network=$(getprop gsm.network.type)"
        echo "sim_state=$(getprop gsm.sim.state)"

        echo
        echo "--- BLUETOOTH ---"
        settings get global bluetooth_on 2>/dev/null

        echo
        echo "--- CAMERA FILES ---"
        find \
            /data/media/0/DCIM/Camera \
            /storage/emulated/0/DCIM/Camera \
            -maxdepth 1 -type f -mmin -15 -ls 2>/dev/null

        echo
        echo "--- TOMBSTONES ---"
        ls -1t /data/tombstones/tombstone_* 2>/dev/null | head -n 5
    } >> "$LOGDIR/timeline.txt" 2>&1

    sleep "$TIMELINE_INTERVAL"
    ELAPSED=$((ELAPSED + TIMELINE_INTERVAL))
done

kill "$LOGCAT_PID" 2>/dev/null
wait "$LOGCAT_PID" 2>/dev/null

dmesg > "$LOGDIR/dmesg_after.txt" 2>&1
snapshot_all "after"
copy_tombstones
make_filtered_logs

{
    echo "capture_finished=$(date)"
    echo "logcat_pid=$LOGCAT_PID"
    echo "output_directory=$LOGDIR"
} >> "$LOGDIR/status.txt" 2>&1

find "$LOGDIR" -type f -exec chmod 0644 {} \; 2>/dev/null
find "$LOGDIR" -type d -exec chmod 0755 {} \; 2>/dev/null

# Keep the directory unpacked for copying from recovery.
# Ownership is deliberately root:root; recovery can read /data directly.
sync
kmsg "done directory=$LOGDIR"
