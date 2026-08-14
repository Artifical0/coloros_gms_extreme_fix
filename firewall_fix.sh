#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR
. "$MODDIR/common.sh"

ensure_runtime_dirs
load_config
[ "$FIREWALL_FIX" = "1" ] || exit 0

# 等待 ColorOS 完成联网防火墙规则初始化。
sleep 60
: > "$FIREWALL_LOG"

if ! resolve_google_uids; then
    log_to "$FIREWALL_LOG" "未解析到 GMS/GSF/Play Store UID；仅处理带明确包名标记的规则"
else
    log_to "$FIREWALL_LOG" "目标 UID：$GOOGLE_UIDS"
fi

chains="fw_INPUT fw_OUTPUT fw_OUTPUT_oplus_dns zte_fw_gms"
for chain in $chains; do
    remove_google_block_rules filter "$chain" ipv4
    remove_google_block_rules filter "$chain" ipv6
done

log_to "$FIREWALL_LOG" "精准防火墙检查完成；未关联 Google 的 DROP/REJECT 保持不变"
