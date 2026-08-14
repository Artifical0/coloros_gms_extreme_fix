#!/system/bin/sh

MODDIR=${0%/*}
export MODDIR
. "$MODDIR/common.sh"

load_config
if [ "$FIREWALL_FIX" = "1" ]; then
    # 手动动作不再等待 60 秒。
    resolve_google_uids
    chains="fw_INPUT fw_OUTPUT fw_OUTPUT_oplus_dns zte_fw_gms"
    for chain in $chains; do
        remove_google_block_rules filter "$chain" ipv4
        remove_google_block_rules filter "$chain" ipv6
    done
    log_to "$FIREWALL_LOG" "手动精准防火墙检查完成"
fi
