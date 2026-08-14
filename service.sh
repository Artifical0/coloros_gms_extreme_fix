#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR
. "$MODDIR/common.sh"

ensure_runtime_dirs
: > "$SERVICE_LOG"
load_config

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

log_to "$SERVICE_LOG" "启动 v3.0：gms_fix=$GMS_FIX firewall_fix=$FIREWALL_FIX wechat_optimize=$WECHAT_OPTIMIZE"

if [ "$GMS_FIX" = "1" ]; then
    capture_runtime_state
    settings put secure google_restric_info 0
    dumpsys deviceidle whitelist +com.google.android.gms > /dev/null 2>&1
    dumpsys deviceidle whitelist +com.google.android.gsf > /dev/null 2>&1
    apply_elsa_patch
else
    log_to "$SERVICE_LOG" "GMS 修复已由 config.conf 禁用"
fi

if [ "$FIREWALL_FIX" = "1" ]; then
    sh "$MODDIR/firewall_fix.sh" &
else
    log_to "$SERVICE_LOG" "防火墙修复已由 config.conf 禁用"
fi
