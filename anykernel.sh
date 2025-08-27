### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=Epicmann24s kernel by epicmann24 @ xda-developers Epicmann24 @ telegram
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot shell variables
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

kernel_version=$(cat /proc/version | awk -F '-' '{print $1}' | awk '{print $3}')
case $kernel_version in
    5.1*) ksu_supported=true ;;
    6.1*) ksu_supported=true ;;
    6.6*) ksu_supported=true ;;
    *) ksu_supported=false ;;
esac

ui_print " " "  -> ksu_supported: $ksu_supported"
$ksu_supported || abort "  -> Non-GKI device, abort."

# boot install
if [ -L "/dev/block/bootdevice/by-name/init_boot_a" -o -L "/dev/block/by-name/init_boot_a" ]; then
    split_boot # for devices with init_boot ramdisk
    flash_boot # for devices with init_boot ramdisk
else
    dump_boot # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk
    write_boot # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
fi
## end boot install


rm -f /data/adb/service.d/kernel-conf.sh
mkdir -p /data/adb/service.d
touch /data/adb/service.d/kernel-conf.sh
rm -f /data/adb/post-fs-data.d/kernel-conf.sh
mkdir -p /data/adb/post-fs-data.d
touch /data/adb/post-fs-data.d/kernel-conf.sh

chmod +x /data/adb/post-fs-data.d/kernel-conf.sh
chmod +x /data/adb/service.d/kernel-conf.sh

cat <<'sd'>> /data/adb/service.d/kernel-conf.sh
#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do
sleep 5
done
sleep 5
echo "off" > /proc/sys/kernel/printk_devkmsg
for disks in /sys/block/*/queue; do
echo 0 > "$disks/iostats"
done
echo 0 > /proc/sys/kernel/sched_schedstats
echo "4674" > /sys/kernel/oplus_display/max_brightness
echo "0" > /sys/devices/system/cpu/pmu_lib/enable_counters
echo "1888" > /sys/class/qcom-haptics/vmax
echo "8300" > /sys/class/qcom-haptics/cl_vmax
echo "11451" > /sys/class/qcom-haptics/fifo_vmax
echo "0 0 0 0" > /proc/sys/kernel/printk
stop statsd
stop criticallog
stop traced
stop traced_probes
stop incidentd
kill -STOP $(pidof dumpstate)
kill -STOP $(pidof tombstoned)

# You may uncomment the following line to acheive better performance/battery, but a small ammount of annoying bank apps may refuse to run
#kill -STOP $(pidof logd)

echo "0 25000" >/proc/shell-temp
echo "1 25000" >/proc/shell-temp
echo "2 25000" >/proc/shell-temp
echo 0 > /sys/class/oplus_chg/battery/cool_down
echo 0 > /sys/class/oplus_chg/battery/normal_cool_down
echo 9100 > /sys/class/oplus_chg/battery/bcc_current
chmod 0444 /sys/class/oplus_chg/battery/bcc_current
chmod 0444 /sys/class/oplus_chg/battery/normal_cool_down
chmod 0444 /sys/class/oplus_chg/battery/cool_down
sd

cat <<'pfsd'>> /data/adb/post-fs-data.d/kernel-conf.sh
#!/system/bin/sh
if ! echo $(uname -r) | grep -q "Epicmann24"; then
rm -rf /data/local/tmp/empty
rm -f /data/adb/service.d/kernel-conf.sh
rm -f /data/adb/post-fs-data.d/kernel-conf.sh
exit 0
fi
sysctl -w vm.stat_interval=4320000
echo 3 > /proc/sys/net/ipv4/tcp_fastopen
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null
echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
echo 16777216 > /proc/sys/net/core/rmem_max 2>/dev/null
echo 16777216 > /proc/sys/net/core/wmem_max 2>/dev/null
echo 4096 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing 2>/dev/null
echo "4096 87380 16777216" > /proc/sys/net/ipv6/tcp_rmem 2>/dev/null
echo "4096 65536 16777216" > /proc/sys/net/ipv6/tcp_wmem 2>/dev/null
resetprop persist.logd.flowctrl.on 0
resetprop persist.logd.flowctrl.method 0
resetprop persist.ims.disableQXDMLogs 1
resetprop persist.vendor.ims.disableADBLogs 1
resetprop persist.sys.log.user 0
resetprop persist.sys.oplus.bt.cache_hcilog_mode 0
resetprop persist.sys.oplus.need_log 0
resetprop persist.sys.ostats_tpd.enable 0
resetprop persist.sys.ostats_pullerd.enable 0
resetprop persist.sys.ostatsd.enable 0
resetprop persist.ims.disableADBLogs 1
resetprop persist.ims.disableDebugLogs 1
resetprop persist.ims.disableIMSLogs 1
resetprop persist.sys.oplus.bt.switch_log.enable false
resetprop persist.anr.dumpthr 0
resetprop persist.sys.enable_adsp_dump 0
resetprop persist.sys.enable_venus_dump 0
resetprop persist.sys.oplus.wifi.fulldump.enable 0
resetprop persist.sys.oplus.cvt.manager false
resetprop persist.sys.oppo.junkmonitor false
resetprop persist.vendor.service.bt.iotinfo.report.enable 0
resetprop persist.sys.tasktracker.enable false
resetprop persist.vendor.tracing.hsuart.enabled 0
resetprop persist.traced.enable 0
resetprop persist.device_config.aconfig_flags.runtime_native_boot.disable_lock_profiling true
resetprop persist.device_config.runtime_native_boot.disable_lock_profiling true
resetprop persist.sys.force_sw_gles 0
resetprop sys.oplus.cvt.enable false
resetprop sys.wifitracing.started 0
resetprop sys.trace.traced_started 0
resetprop sys.oplus.wifi.dump.needupload 0
resetprop sys.oplus.wifi.dump.enable 0
resetprop ro.oplus.minidump.kernel.log.support 0
resetprop ro.oplus.wifi.minidump.enable.state 0
resetprop ro.vendor.oplus.modemdump_enable 0
resetprop ro.logd.flowctrl.on 0
resetprop ro.logd.flowctrl.method 0
resetprop ro.oplus.osense.uaf_enable false
resetprop ro.oplus.osense.uaf_key_thread_enable false
resetprop ro.oplus.osense.uaf_vip_binder_enable false
resetprop ro.oplus.audio.thermal_control false
resetprop debug.oplus.video.log.enable 0
resetprop debug.sf.oplus_display_trace.enable 0
resetprop debug.c2.use_dmabufheaps 0
resetprop vendor.swvdec.log.level 0
resetprop dalvik.vm.dex2oat-minidebuginfo 0
resetprop dalvik.vm.minidebuginfo 0
resetprop oplus.dex.tempcontrol false

resetprop ro.oplus.radio.global_regionlock.log 0
resetprop ro.boot.veritymode enforcing
resetprop ro.boot.verifiedbootstate green

mkdir -p /data/local/tmp/empty

mount --bind /data/local/tmp/empty /product/priv-app/Facebook-installer
mount --bind /data/local/tmp/empty /product/app/Facebook-appmanager

pfsd
