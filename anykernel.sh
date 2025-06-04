### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=Epicmann24s kernel by epicmann24 @ xda-developers epkmn @ telegram
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

# ===START DTBO PATCH===

#Credits to bybycode

MODPATH=$(dirname "$(readlink -f "$0")")

lfdtget=$MODPATH/bin/fdtget
lfdtput=$MODPATH/bin/fdtput

PATCH_DTB() {
    ui_print "Patching $1"
    local lfinded=0
    local alpatched=0

    for i in $($lfdtget $1 /__fixups__ soc); do
        local lpath=$(echo $i | sed 's/\:target\:0//g')
        if $lfdtget -l $1 ${lpath}/__overlay__ | grep -q hmbird; then
            if [ $($lfdtget $1 ${lpath}/__overlay__/oplus,hmbird/version_type type) == "HMBIRD_GKI" ]; then
                alpatched=1
                ui_print "$1 has been patched"
            fi
            break
        fi
    done

    if [ $alpatched -eq 0 ]; then
        for i in $($lfdtget $1 /__fixups__ soc); do
            local lpath=$(echo $i | sed 's/\:target\:0//g')
            if $lfdtget -l $1 ${lpath}/__overlay__ | grep -q hmbird; then
                local lfinded=1
                ui_print "- $1 Found DTBO patch location"
                $lfdtput -t s $1 ${lpath}/__overlay__/oplus,hmbird/version_type type HMBIRD_GKI
                break
            fi
        done

        if [ $lfinded -eq 0 ]; then
            ui_print "- Add patches for non GKI: $1"
            for i in $($lfdtget $1 /__fixups__ soc); do
                local ppath=$(echo $i | sed 's/\:target\:0//g')
                if $lfdtget -l $1 ${ppath}/__overlay__ | grep -q reboot_reason; then
                    $lfdtput -p -c $1 ${ppath}/__overlay__/oplus,hmbird/version_type
                    $lfdtput -t s $1 ${ppath}/__overlay__/oplus,hmbird/version_type type HMBIRD_GKI
                    break
                fi
            done
        fi
    fi
}

REPACKDTBO() {
    ui_print ""
    ui_print ""
    ui_print "Start DTBO patch"
    ui_print ""
    ui_print ""
    LMKDT=$MODPATH/bin/mkdtimg
    ui_print "Unpacking DTBO"
    $LMKDT dump $DTBOTMP -b dtb >/dev/null 2>&1
    wait

    for i in dtb.*; do
        PATCH_DTB $i &
    done
    wait
    ui_print "Packaging DTBO"

    $LMKDT create $DTBOTMP --page_size=4096 dtb.* >/dev/null 2>&1
    wait
}

model=$(getprop ro.product.vendor.name)
ui_print "Model code: $model"
ui_print ""

DTBO_PARTI="/dev/block/bootdevice/by-name/dtbo$(getprop ro.boot.slot_suffix)"
DTBOTMP="${TMPDIR}/dtbo.img"

chmod +x $MODPATH/bin/*
dd if=$DTBO_PARTI of=$DTBOTMP
REPACKDTBO
ui_print ""
ui_print ""
ui_print "Flashing DTBO"
dd if=$DTBOTMP of=$DTBO_PARTI

rm -r $MODPATH/bin
rm -r $MODPATH/patch

# ===END DTBO PATCH===

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
stop statsd
stop tombstoned
stop criticallog
stop traced
stop traced_probes
sd

cat <<'pfsd'>> /data/adb/post-fs-data.d/kernel-conf.sh
#!/system/bin/sh
if ! echo $(uname -r) | grep -q "Epicmann24"; then
rm -f /data/adb/service.d/kernel-conf.sh
rm -f /data/adb/post-fs-data.d/kernel-conf.sh
exit 0
fi
echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null
echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
echo 16777216 > /proc/sys/net/core/rmem_max 2>/dev/null
echo 16777216 > /proc/sys/net/core/wmem_max 2>/dev/null
echo 4096 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing 2>/dev/null
echo 1 > /proc/sys/net/ipv6/tcp_ecn 2>/dev/null
echo "4096 87380 16777216" > /proc/sys/net/ipv6/tcp_rmem 2>/dev/null
echo "4096 65536 16777216" > /proc/sys/net/ipv6/tcp_wmem 2>/dev/null
resetprop persist.logd.flowctrl.on 0
resetprop persist.logd.flowctrl.method 0
resetprop ro.logd.flowctrl.on 0
resetprop ro.logd.flowctrl.method 0
resetprop debug.oplus.video.log.enable 0
resetprop persist.sys.log.user 0
resetprop persist.sys.oplus.bt.cache_hcilog_mode 0
resetprop persist.sys.oplus.need_log 0
resetprop vendor.swvdec.log.level 0
resetprop persist.sys.ostats_tpd.enable 0
resetprop persist.sys.ostats_pullerd.enable 0
resetprop persist.sys.ostatsd.enable 0
resetprop debug.sf.oplus_display_trace.enable 0
resetprop net.core.default_qdisc fq
resetprop net.ipv4.tcp_congestion_control bbr
mount --bind /data/local/tmp/empty /system_ext/app/CrashBox
mount --bind /data/local/tmp/empty /system_ext/app/EidService
mount --bind /data/local/tmp/empty /system_ext/app/LogKit
mount --bind /data/local/tmp/empty /system_ext/app/Olc
mount --bind /data/local/tmp/empty /system_ext/app/OplusLocationService
mount --bind /data/local/tmp/empty /system_ext/app/OTrace
mount --bind /data/local/tmp/empty /system_ext/app/QCC
mount --bind /data/local/tmp/empty /system_ext/app/LFEHer
mount --bind /data/local/tmp/empty /system_ext/app/OplusQualityProtect
mount --bind /data/local/tmp/empty /system_ext/priv-app/com.qualcomm.location
mount --bind /data/local/tmp/empty /product/app/StdSP
mount --bind /data/local/tmp/empty /product/app/LocationProxy
mount --bind /data/local/tmp/empty /product/priv-app/DCS
mount --bind /data/local/tmp/empty /product/priv-app/Metis
mount --bind /data/local/tmp/empty /vendor/app/TxPwrAdmin
mount --bind /data/local/tmp/empty /vendor/app/TrustZoneAccessService
mount --bind /data/local/tmp/empty /system_ext/priv-app/xrvdservice
mount --bind /data/local/tmp/empty /product/app/DeviceStatisticsService
mount --bind /data/local/tmp/empty /system_ext/app/OwkService
mount --bind /data/local/tmp/empty /my_stock/non_overlay/app/OBrain
pfsd

