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

MODPATH=$(dirname "$(readlink -f "$0")")
ui_print "Disabling AVB"
$MODPATH/bin/avbctl disable-verity --force
$MODPATH/bin/avbctl disable-verification --force

# ===START DTBO PATCH===

# Credits to bybycode

lfdtget=$MODPATH/bin/fdtget
lfdtput=$MODPATH/bin/fdtput

PATCH3_VOOC_PPSPROTO=$MODPATH/patch/patch3_vooc_ppsproto
PATCH4_COMMON=$MODPATH/patch/patch4_common
PATCH4_BATT_THERM=$MODPATH/patch/patch4_batt_therm
PATCH4_PPS=$MODPATH/patch/patch4_pps
PATCH4_UFCS=$MODPATH/patch/patch4_ufcs

RMTHERM=$MODPATH/patch/remove_therm
RMDDRC=$MODPATH/patch/remove_ddrc
RMDSITIMMING=$MODPATH/patch/remove_dsi_timming

patch_batt_therm=1 # loosen battery‐thermal limits
patch_pps=1        # enable third‐party 55W PPS
patch_ufcs=1       # enable UFCS mod
rm_therm=1         # remove on-chip thermal controls
rm_ddrc=1          # remove DDRC node(s)
rm_dsi_timming=1   # remove DSI timing overrides

find_prop_symbols() {
    $lfdtget "$1" /__symbols__ "$2"
}
find_prop_symbols_head() {
    $lfdtget "$1" /__symbols__ "$2" | sed -E 's#^(/fragment@[0-9]+).*#\1#'
}
find_prop_fixups_head() {
    $lfdtget "$1" /__fixups__ "$2" | sed -E 's#^(/fragment@[0-9]+).*#\1#'
}

set3_prop() {
    local mode="$1"
    local dtbfile="$2"
    local propname="$3"
    local value="$4"
    local nodepath
    nodepath="$(find_prop_symbols "$dtbfile" "$propname")"
    shift 4
    "$lfdtput" -t "$mode" "$dtbfile" "$nodepath" "$value" "$@"
    wait
}

set4_prop() {
    local mode="$1"
    local dtbfile="$2"
    local propname="$3"
    local subnode="$4"
    local value="$5"
    local nodepath
    nodepath="$(find_prop_symbols "$dtbfile" "$propname")"
    shift 5
    "$lfdtput" -t "$mode" "$dtbfile" "$nodepath"/"$subnode" "$value" "$@"
    wait
}

rmr_prop() {
    local dtbfile="$1"
    local flag="$2"
    local propname="$3"
    local child="$4"
    local nodepath
    nodepath="$(find_prop_symbols "$dtbfile" "$propname")"
    "$lfdtput" -"${flag}" -v "$dtbfile" "$nodepath"/"$child"
    wait
}

rmd_prop() {
    local dtbfile="$1"
    local flag="$2"
    local propname="$3"
    local todel="$4"
    local nodepath
    nodepath="$(find_prop_symbols "$dtbfile" "$propname")"
    "$lfdtput" -"${flag}" -v "$dtbfile" "$nodepath" "$todel"
    wait
}

fgrmr_prop() {
    local dtbfile="$1"
    local flag="$2"
    local propname="$3"
    local child="$4"
    local nodepath
    nodepath="$(find_prop_fixups_head "$dtbfile" "$propname")"
    "$lfdtput" -"${flag}" -v "$dtbfile" "$nodepath"/"$child"
    wait
}

fgfrmr_prop() {
    local dtbfile="$1"
    local flag="$2"
    local propname="$3"
    local child="$4"
    local nodepath
    nodepath="$(find_prop_fixups_head "$dtbfile" "$propname")"
    "$lfdtput" -"${flag}" -v "$dtbfile" "$nodepath"/"$child"
    wait
}

rm_proc_from_file() {
    local filelist="$1"
    local dtbfile="$2"
    while IFS= read -r line; do
        op="$(echo "$line" | awk '{print $1}')"
        case "$op" in
            r)
                prop="$(echo "$line" | awk '{print $2}')"
                child="$(echo "$line" | awk '{print $3}')"
                rmr_prop "$dtbfile" "r" "$prop" "$child"
                ;;
            d)
                prop="$(echo "$line" | awk '{print $2}')"
                todel="$(echo "$line" | awk '{print $3}')"
                rmd_prop "$dtbfile" "d" "$prop" "$todel"
                ;;
            fgr)
                prop="$(echo "$line" | awk '{print $2}')"
                child="$(echo "$line" | awk '{print $3}')"
                fgrmr_prop "$dtbfile" "r" "$prop" "$child"
                ;;
            fgfr)
                prop="$(echo "$line" | awk '{print $2}')"
                child="$(echo "$line" | awk '{print $3}')"
                fgfrmr_prop "$dtbfile" "r" "$prop" "$child"
                ;;
        esac
    done <"$filelist"
}

namemark() {
    local dtbfile="$1"
    local tag="$2"
    local modelstr
    modelstr="$("$lfdtget" -t s "$dtbfile" / model | sed 's/jzmod_.*//g')"
    datesuffix="$(date +%y-%m-%d_%H-%M-%S)"
    "$lfdtput" -t s "$dtbfile" / model "${modelstr} jzmod_${tag}_${datesuffix}"
    wait
}

PATCH_DTB() {
    local dtbfile="$1"
    ui_print "Patching $dtbfile"
    local fg_count=0

    for i in $(seq 1 60); do
        if "$lfdtget" -l "$dtbfile" /fragment@"${i}"/__overlay__ 2>/dev/null | grep -q shell; then
            fg_count="$i"
            break
        fi
    done

    if [ "$patch_hm" -eq 1 ]; then
        for fix in $("$lfdtget" "$dtbfile" /__fixups__ soc); do
            local path="$(echo "$fix" | sed 's/\:target\:0//g')"
            if "$lfdtget" -l "$dtbfile" "${path}"/__overlay__ | grep -q hmbird; then
                "$lfdtput" -r "$dtbfile" "${path}"/__overlay__/oplus,hmbird
                break
            fi
        done
        "$lfdtput" -p -c "$dtbfile" /fragment@"${fg_count}"/__overlay__/oplus,hmbird/version_type
        "$lfdtput" -t s "$dtbfile" /fragment@"${fg_count}"/__overlay__/oplus,hmbird/version_type type HMBIRD_GKI
    fi

    while IFS= read -r line; do
        set3_prop x "$dtbfile" $line
    done <"$PATCH3_VOOC_PPSPROTO"

    while IFS= read -r line; do
        set4_prop x "$dtbfile" $line
    done <"$PATCH4_COMMON"

    if [ "$patch_batt_therm" -eq 1 ]; then
        while IFS= read -r line; do
            set4_prop x "$dtbfile" $line
        done <"$PATCH4_BATT_THERM"
    fi

    if [ "$patch_pps" -eq 1 ]; then
        while IFS= read -r line; do
            set4_prop x "$dtbfile" $line
        done <"$PATCH4_PPS"
    fi

    if [ "$patch_ufcs" -eq 1 ]; then
        while IFS= read -r line; do
            set4_prop x "$dtbfile" $line
        done <"$PATCH4_UFCS"
    fi

    ui_print " → Removals for $dtbfile"
    if [ "$rm_therm" -eq 1 ]; then
        "$lfdtput" -r "$dtbfile" /fragment@"${fg_count}"/__overlay__/shell_front
        "$lfdtput" -r "$dtbfile" /fragment@"${fg_count}"/__overlay__/shell_frame
        "$lfdtput" -r "$dtbfile" /fragment@"${fg_count}"/__overlay__/shell_back

        rm_proc_from_file "$RMTHERM" "$dtbfile"

        local fg_path
        fg_path="$(find_prop_fixups_head "$dtbfile" modem_lte_dsc)"
        for sub in \
            socd/cooling-maps \
            pmih010x-bcl-lvl0/cooling-maps \
            pmih010x-bcl-lvl1/cooling-maps \
            pmih010x-bcl-lvl2/cooling-maps \
            pm8550-bcl-lvl0/cooling-maps \
            pm8550-bcl-lvl1/cooling-maps \
            pm8550-bcl-lvl2/cooling-maps \
            pm8550vs_f_tz/cooling-maps \
            pm8550ve_f_tz/cooling-maps \
            pm8550vs_j_tz/cooling-maps \
            pm8550ve_d_tz/cooling-maps \
            pm8550ve_g_tz/cooling-maps \
            pm8550ve_i_tz/cooling-maps \
            sys-therm-0/cooling-maps/apc1_cdev \
            sys-therm-0/cooling-maps/apc0_cdev \
            sys-therm-0/cooling-maps/cdsp_cdev \
            sys-therm-0/cooling-maps/gpu_cdev \
            sys-therm-0/cooling-maps/lte_cdev \
            sys-therm-0/cooling-maps/nr_cdev \
            sys-therm-0/cooling-maps/display_cdev1 \
            sys-therm-0/cooling-maps/display_cdev2 \
            sys-therm-0/cooling-maps/display_cdev3 \
            sys-therm-2/cooling-maps/gpu_dump_skip
        do
            "$lfdtput" -r "$dtbfile" /__local_fixups__/"${fg_path}"/__overlay__/"$sub"
        done

        for fx in \
            APC1_MX_CX_PAUSE \
            cdsp_sw \
            msm_gpu \
            modem_bcl \
            APC0_MX_CX_PAUSE \
            cdsp_sw_hvx \
            modem_lte_dsc \
            modem_nr_dsc \
            cdsp_sw_hmx \
            modem_nr_scg_dsc \
            display_fps
        do
            "$lfdtput" -d "$dtbfile" /__fixups__ "$fx"
        done
    fi

    if [ "$rm_ddrc" -eq 1 ]; then
        rm_proc_from_file "$RMDDRC" "$dtbfile"
    fi

    if [ "$rm_dsi_timming" -eq 1 ]; then
        rm_proc_from_file "$RMDSITIMMING" "$dtbfile"
    fi

    namemark "$dtbfile" "$(basename "$dtbfile")"
}

REPACKDTBO() {
    ui_print ""
    ui_print ""
    ui_print "Start DTBO patch"
    ui_print ""
    ui_print ""
    LMKDT=$MODPATH/bin/mkdtimg
    ui_print "Unpacking $DTBO_PARTI"
    $LMKDT dump "$DTBOTMP" -b dtb >/dev/null 2>&1
    wait

    count=$(for f in dtb.*; do
            strings "$f" | grep -c "hmbird"
            done | awk '{s+=$1} END{print s}')

    if [ "$count" -ge 3 ]; then
        patch_hm=0
        ui_print " "
        ui_print " "
        ui_print "Your DTBO is already patched (found $count hmbird marks), skipping GKI patch."
        ui_print " "
        ui_print " "
        ui_print "It is recomended to flash stock dtbo and boot before flashing kernel"
        ui_print "If everything is working fine then dont worry, if there is issues then this should be your first troubleshooting step"
        ui_print " "
        ui_print " "
        ui_print "Resuming flashing"
        ui_print " "
        ui_print " "
    else
        patch_hm=1
    fi

    for i in dtb.*; do
        PATCH_DTB "$i" &
    done
    wait

    ui_print "Packaging $DTBO_PARTI"
    $LMKDT create "$DTBOTMP" --page_size=4096 dtb.* >/dev/null 2>&1
    wait
}

model=$(getprop ro.product.vendor.name)
ui_print "Model code: $model"
ui_print ""

chmod +x $MODPATH/bin/*

for suffix in _a _b; do
    PART="/dev/block/bootdevice/by-name/dtbo${suffix}"
    if [ -e "$PART" ]; then
        DTTMP="${TMPDIR}/dtbo${suffix}.img"
        DTBO_PARTI="$PART"
        DTBOTMP="$DTTMP"
        ui_print "Processing $DTBO_PARTI..."
        dd if="$DTBO_PARTI" of="$DTBOTMP"
        REPACKDTBO
        ui_print ""
        ui_print ""
        ui_print "Flashing $DTBO_PARTI"
        dd if="$DTBOTMP" of="$DTBO_PARTI"
    fi
done

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
echo "0 0 0 0" > /proc/sys/kernel/printk
stop statsd
stop criticallog
stop traced
stop traced_probes
kill -STOP $(pidof tombstoned)
kill -STOP $(pidof logd)

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
resetprop persist.ims.disablelMSLogs 1
resetprop persist.sys.oplus.bt.switch_log.enable false
resetprop persist.anr.dumpthr 0
resetprop persist.sys.enable_adsp_dump 0
resetprop persist.sys.enable_venus_dump 0
resetprop persist.sys.oplus.wifi.fulldump.enable 0
resetprop sys.wifitracing.started 0
resetprop sys.trace.traced_started 0
resetprop sys.oplus.wifi.dump.needupload 0
resetprop sys.oplus.wifi.dump.enable 0
resetprop ro.oplus.minidump.kernel.log.support 0
resetprop ro.oplus.wifi.minidump.enable.state 0
resetprop ro.vendor.oplus.modemdump_enable 0
resetprop ro.logd.flowctrl.on 0
resetprop ro.logd.flowctrl.method 0
resetprop debug.oplus.video.log.enable 0
resetprop debug.sf.oplus_display_trace.enable 0
resetprop vendor.swvdec.log.level 0

resetprop ro.oplus.radio.global_regionlock.log 0
resetprop net.core.default_qdisc fq
resetprop net.ipv4.tcp_congestion_control bbr
resetprop ro.boot.veritymode enforcing

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

psd
