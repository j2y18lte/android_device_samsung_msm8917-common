#! /vendor/bin/sh
# Copyright (c) 2012-2013, 2016, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function write_if_exists() {
    node="$1"
    value="$2"

    if [ -e "$node" ]; then
        echo "$value" > "$node"
    fi
}

function configure_memory_parameters() {
    # Keep kernel LMK enabled. Android lmkd still controls adj/minfree.
    write_if_exists /sys/module/lowmemorykiller/parameters/enable_lmk 1

    # Conservative Adaptive LMK for a low-RAM device.
    write_if_exists /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk 1
    write_if_exists /sys/module/lowmemorykiller/parameters/adj_max_shift 850
    write_if_exists /sys/module/lowmemorykiller/parameters/vmpressure_file_min 32768

    # Process reclaim is useful only when zRAM is active.
    if grep -q 'zram0' /proc/swaps; then
        write_if_exists /sys/module/process_reclaim/parameters/pressure_min 50
        write_if_exists /sys/module/process_reclaim/parameters/pressure_max 90
        write_if_exists /sys/module/process_reclaim/parameters/per_swap_size 512
        write_if_exists /sys/module/process_reclaim/parameters/swap_opt_eff 30
        write_if_exists /sys/module/process_reclaim/parameters/min_score_adj 850
        write_if_exists /sys/module/process_reclaim/parameters/enable_process_reclaim 1
        log -t qcom-post-boot "zRAM active; ALMK and process_reclaim enabled"
    else
        write_if_exists /sys/module/process_reclaim/parameters/enable_process_reclaim 0
        log -t qcom-post-boot "zRAM inactive; process_reclaim disabled"
    fi

    # Optional legacy Qualcomm zcache tuning.
    read MemKey MemTotal MemUnit < /proc/meminfo
    if [ -n "$MemTotal" ] && [ "$MemTotal" -gt 0 ]; then
        MemTotalPg=$((MemTotal / 4))
        clearPercent=$((((15360 * 100) / MemTotalPg) + 1))
        write_if_exists /sys/module/zcache/parameters/clear_percent "$clearPercent"
    fi
    write_if_exists /sys/module/zcache/parameters/max_pool_percent 30
}

case "$target" in
    "msm7201a_ffa" | "msm7201a_surf" | "msm7627_ffa" | "msm7627_6x" | "msm7627a"  | "msm7627_surf" | \
    "qsd8250_surf" | "qsd8250_ffa" | "msm7630_surf" | "msm7630_1x" | "msm7630_fusion" | "qsd8650a_st1x")
        echo "ondemand" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo 90 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
        ;;
esac

case "$target" in
    "msm7201a_ffa" | "msm7201a_surf")
        echo 500000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
        ;;
esac

case "$target" in
    "msm7630_surf" | "msm7630_1x" | "msm7630_fusion")
        echo 75000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
        echo 1 > /sys/module/pm2/parameters/idle_sleep_mode
        ;;
esac

case "$target" in
     "msm7201a_ffa" | "msm7201a_surf" | "msm7627_ffa" | "msm7627_6x" | "msm7627_surf" | "msm7630_surf" | "msm7630_1x" | "msm7630_fusion" | "msm7627a" )
        echo 245760 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        ;;
esac

case "$target" in
    "msm8660")
     echo 1 > /sys/module/rpm_resources/enable_low_power/L2_cache
     echo 1 > /sys/module/rpm_resources/enable_low_power/pxo
     echo 2 > /sys/module/rpm_resources/enable_low_power/vdd_dig
     echo 2 > /sys/module/rpm_resources/enable_low_power/vdd_mem
     echo 1 > /sys/module/rpm_resources/enable_low_power/rpm_cpu
     echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/suspend_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/suspend_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/suspend_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/suspend_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/idle_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/idle_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/idle_enabled
     echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/idle_enabled
     echo "ondemand" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
     echo "ondemand" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
     echo 50000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
     echo 90 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
     echo 1 > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
     echo 4 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
     echo 384000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
     echo 384000 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
     chown -h system /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
     chown -h system /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
     chown -h system /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
     chown -h system /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
     chown -h root.system /sys/devices/system/cpu/mfreq
     chmod -h 220 /sys/devices/system/cpu/mfreq
     chown -h root.system /sys/devices/system/cpu/cpu1/online
     chmod -h 664 /sys/devices/system/cpu/cpu1/online
        ;;
esac

case "$target" in
    "msm8937")

        if [ -f /sys/devices/soc0/soc_id ]; then
            soc_id=`cat /sys/devices/soc0/soc_id`
        else
            soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi

        if [ -f /sys/devices/soc0/hw_platform ]; then
            hw_platform=`cat /sys/devices/soc0/hw_platform`
        else
            hw_platform=`cat /sys/devices/system/soc/soc0/hw_platform`
        fi
	if [ -f /sys/devices/soc0/platform_subtype_id ]; then
	    platform_subtype_id=`cat /sys/devices/soc0/platform_subtype_id`
        fi

        case "$soc_id" in
           "303" | "307" | "308" | "309" | "320" )

                  # Start Host based Touch processing
                  case "$hw_platform" in
                    "Surf" | "RCM" )
			if [ $platform_subtype_id -ne "4" ]; then
			    start_hbtp
		        fi
                        ;;
                  esac
                # Apply Scheduler and Governor settings for 8917 / 8920

                # HMP scheduler settings
                echo 3 > /proc/sys/kernel/sched_window_stats_policy
                echo 3 > /proc/sys/kernel/sched_ravg_hist_size
                echo 20000000 > /proc/sys/kernel/sched_ravg_window
                echo 1 > /proc/sys/kernel/sched_restrict_tasks_spread
                echo 1 > /proc/sys/kernel/sched_wake_to_idle

                #disable sched_boost in 8917
                echo 0 > /proc/sys/kernel/sched_boost

                # HMP Task packing settings
                echo 20 > /proc/sys/kernel/sched_small_task
                echo 30 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_load

                echo 3 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_nr_run

                echo 0 > /sys/devices/system/cpu/cpu0/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu1/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu2/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu3/sched_prefer_idle

		# core_ctl is not needed for 8917. Disable it.
		#echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/disable

                for devfreq_gov in /sys/class/devfreq/qcom,mincpubw*/governor
                do
                    echo "cpufreq" > $devfreq_gov
                done

                for devfreq_gov in /sys/class/devfreq/soc:qcom,cpubw/governor
                do
                    echo "bw_hwmon" > $devfreq_gov
                    for cpu_io_percent in /sys/class/devfreq/soc:qcom,cpubw/bw_hwmon/io_percent
                    do
                        echo 20 > $cpu_io_percent
                    done
                for cpu_guard_band in /sys/class/devfreq/soc:qcom,cpubw/bw_hwmon/guard_band_mbps
                    do
                        echo 30 > $cpu_guard_band
                    done
                done

                for gpu_bimc_io_percent in /sys/class/devfreq/soc:qcom,gpubw/bw_hwmon/io_percent
                do
                    echo 40 > $gpu_bimc_io_percent
                done

                # disable thermal core_control to update interactive gov settings
                echo 0 > /sys/module/msm_thermal/core_control/enabled

                echo 1 > /sys/devices/system/cpu/cpu0/online
                echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
                echo "19000 1094400:39000" > /sys/devices/system/cpu/cpufreq/interactive/above_hispeed_delay
                echo 85 > /sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load
                echo 20000 > /sys/devices/system/cpu/cpufreq/interactive/timer_rate
                echo 1094400 > /sys/devices/system/cpu/cpufreq/interactive/hispeed_freq
                echo 0 > /sys/devices/system/cpu/cpufreq/interactive/io_is_busy
                echo "1 960000:85 1094400:90" > /sys/devices/system/cpu/cpufreq/interactive/target_loads
                echo 40000 > /sys/devices/system/cpu/cpufreq/interactive/min_sample_time
                echo 40000 > /sys/devices/system/cpu/cpufreq/interactive/sampling_down_factor
                echo 960000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
                # re-enable thermal core_control now
                echo 1 > /sys/module/msm_thermal/core_control/enabled

                #lpm disable freq
                chown radio.system sys/devices/system/cpu/cpufreq/interactive/io_is_busy
                chmod 664 sys/devices/system/cpu/cpufreq/interactive/io_is_busy
                echo 1094400 > /sys/devices/system/cpu/cpufreq/interactive/lpm_disable_freq
                chown root.root sys/devices/system/cpu/cpufreq/interactive/lpm_disable_freq
				
                # Disable L2-GDHS low power modes
                echo N > /sys/module/lpm_levels/perf/perf-l2-gdhs/idle_enabled
                echo N > /sys/module/lpm_levels/perf/perf-l2-gdhs/suspend_enabled

                # Bring up all cores online
                echo 1 > /sys/devices/system/cpu/cpu1/online
                echo 1 > /sys/devices/system/cpu/cpu2/online
                echo 1 > /sys/devices/system/cpu/cpu3/online

                # Enable low power modes
                echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

                # Enable sched guided freq control
                echo 1 > /sys/devices/system/cpu/cpufreq/interactive/use_sched_load
                echo 1 > /sys/devices/system/cpu/cpufreq/interactive/use_migration_notif
                echo 50000 > /proc/sys/kernel/sched_freq_inc_notify
                echo 50000 > /proc/sys/kernel/sched_freq_dec_notify

                #change governor node permission
                chown radio.system /sys/devices/system/cpu/cpufreq/interactive/io_is_busy
                chmod 664 /sys/devices/system/cpu/cpufreq/interactive/io_is_busy

                # Set rps mask
                echo 2 > /sys/class/net/rmnet0/queues/rx-0/rps_cpus

                # Enable dynamic clock gating
                echo 1 > /sys/module/lpm_levels/lpm_workarounds/dynamic_clock_gating
                # Enable timer migration to little cluster
                echo 1 > /proc/sys/kernel/power_aware_timer_migration

                #control daemon for xosd
                factory_mode=`getprop ro.factory.factory_binary`
                if [ "$factory_mode" != "factory" ]; then
                        jig_mode=`cat /sys/class/switch/uart3/state`
                        case "$jig_mode" in
                            1)
                                echo "PM: JIG UART" > /dev/kmsg
                            ;;
                            0)
                                echo "PM: stop at_distributor" > /dev/kmsg
                                stop at_distributor
                                stop diag_uart_log
                            ;;
                        esac
                fi

                # Set Memory parameters
                configure_memory_parameters
                ;;
                *)
                ;;
        esac

        case "$soc_id" in
             "294" | "295" | "313" )

                  # Start Host based Touch processing
                  case "$hw_platform" in
                    "MTP" | "Surf" | "RCM" )
                        start hbtp
                        ;;
                  esac

                # Apply Scheduler and Governor settings for 8937/8940

                # HMP scheduler settings
                echo 3 > /proc/sys/kernel/sched_window_stats_policy
                echo 3 > /proc/sys/kernel/sched_ravg_hist_size
                echo 20000000 > /proc/sys/kernel/sched_ravg_window

                #disable sched_boost in 8937
                echo 0 > /proc/sys/kernel/sched_boost

                # HMP Task packing settings
                echo 20 > /proc/sys/kernel/sched_small_task
                echo 30 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu4/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu5/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu6/sched_mostly_idle_load
                echo 30 > /sys/devices/system/cpu/cpu7/sched_mostly_idle_load

                echo 3 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu4/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu5/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu6/sched_mostly_idle_nr_run
                echo 3 > /sys/devices/system/cpu/cpu7/sched_mostly_idle_nr_run

                echo 0 > /sys/devices/system/cpu/cpu0/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu1/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu2/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu3/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu4/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu5/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu6/sched_prefer_idle
                echo 0 > /sys/devices/system/cpu/cpu7/sched_prefer_idle

                for devfreq_gov in /sys/class/devfreq/qcom,mincpubw*/governor
                do
                    echo "cpufreq" > $devfreq_gov
                done

                for devfreq_gov in /sys/class/devfreq/soc:qcom,cpubw/governor
                do
                    echo "bw_hwmon" > $devfreq_gov
                    for cpu_io_percent in /sys/class/devfreq/soc:qcom,cpubw/bw_hwmon/io_percent
                    do
                        echo 20 > $cpu_io_percent
                    done
                for cpu_guard_band in /sys/class/devfreq/soc:qcom,cpubw/bw_hwmon/guard_band_mbps
                    do
                        echo 30 > $cpu_guard_band
                    done
                done

                for gpu_bimc_io_percent in /sys/class/devfreq/soc:qcom,gpubw/bw_hwmon/io_percent
                do
                    echo 40 > $gpu_bimc_io_percent
                done

                # disable thermal core_control to update interactive gov and core_ctl settings
                echo 0 > /sys/module/msm_thermal/core_control/enabled

                # enable governor for perf cluster
                echo 1 > /sys/devices/system/cpu/cpu0/online
                echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
                echo "19000 1094400:39000" > /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay
                echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load
                echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate
                echo 1094400 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq
                echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
                echo "1 960000:85 1094400:90 1344000:80" > /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads
                echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time
                echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/sampling_down_factor
                echo 960000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

                # enable governor for power cluster
                echo 1 > /sys/devices/system/cpu/cpu4/online
                echo "interactive" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
                echo 39000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/above_hispeed_delay
                echo 90 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/go_hispeed_load
                echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/timer_rate
                echo 768000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/hispeed_freq
                echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/io_is_busy
                echo "1 768000:90" > /sys/devices/system/cpu/cpu4/cpufreq/interactive/target_loads
                echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/min_sample_time
                echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/sampling_down_factor
                echo 768000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq

                # Disable L2-GDHS low power modes
                echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled
                echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/suspend_enabled
                echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled
                echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/suspend_enabled

                # Bring up all cores online
                echo 1 > /sys/devices/system/cpu/cpu1/online
                echo 1 > /sys/devices/system/cpu/cpu2/online
                echo 1 > /sys/devices/system/cpu/cpu3/online
                echo 1 > /sys/devices/system/cpu/cpu4/online
                echo 1 > /sys/devices/system/cpu/cpu5/online
                echo 1 > /sys/devices/system/cpu/cpu6/online
                echo 1 > /sys/devices/system/cpu/cpu7/online

                # Enable low power modes
                echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

                # HMP scheduler (big.Little cluster related) settings
                echo 93 > /proc/sys/kernel/sched_upmigrate
                echo 83 > /proc/sys/kernel/sched_downmigrate

                # Enable sched guided freq control
                echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load
                echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif
                echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_sched_load
                echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_migration_notif
                echo 50000 > /proc/sys/kernel/sched_freq_inc_notify
                echo 50000 > /proc/sys/kernel/sched_freq_dec_notify

                # Enable core control
                echo 2 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
                echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/max_cpus
                echo 68 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
                echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
                echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
                echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/is_big_cluster

                # re-enable thermal core_control
                echo 1 > /sys/module/msm_thermal/core_control/enabled

                # Enable dynamic clock gating
                echo 1 > /sys/module/lpm_levels/lpm_workarounds/dynamic_clock_gating
                # Enable timer migration to little cluster
                echo 1 > /proc/sys/kernel/power_aware_timer_migration
                # Set Memory parameters
                configure_memory_parameters
            ;;
            *)

            ;;
        esac
    ;;
esac

chown -h system /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
chown -h system /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
chown -h system /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy

emmc_boot=`getprop ro.boot.emmc`
case "$emmc_boot"
    in "true")
        chown -h system /sys/devices/platform/rs300000a7.65536/force_sync
        chown -h system /sys/devices/platform/rs300000a7.65536/sync_sts
        chown -h system /sys/devices/platform/rs300100a7.65536/force_sync
        chown -h system /sys/devices/platform/rs300100a7.65536/sync_sts
    ;;
esac

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.console.silent.config`
case "$console_config" in
    "1")
        echo "Enable console config to $console_config"
        echo 0 > /proc/sys/kernel/printk
        ;;
    *)
        echo "Enable console config to $console_config"
        ;;
esac

# Notify Qualcomm Perf HAL that post-boot configuration is complete
setprop vendor.post_boot.parsed 1
log -t qcom-post-boot "vendor.post_boot.parsed=$(getprop vendor.post_boot.parsed)"

exit 0
