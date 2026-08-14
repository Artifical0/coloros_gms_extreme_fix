#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

for script in "$ROOT"/*.sh; do
    bash -n "$script"
done

export MODDIR="$ROOT"
export CONFIG_FILE="$ROOT/config.conf"
export LOG_DIR="$TMP_DIR/logs"
export SERVICE_LOG="$LOG_DIR/service.log"
export FIREWALL_LOG="$LOG_DIR/firewall.log"
export ELSA_WORK="$TMP_DIR/work/patched.xml"
export STATE_DIR="$TMP_DIR/state"

# shellcheck source=../common.sh
source "$ROOT/common.sh"
load_config

build_elsa_patch "$ROOT/tests/fixtures/elsa_sample.xml" "$ELSA_WORK"

grep -q '<version>rom-version-must-stay</version>' "$ELSA_WORK"
grep '<whitePkg[^>]*name="com.google.android.gms"' "$ELSA_WORK" | grep -q 'category="100"'
grep '<whitePkg[^>]*name="com.google.android.gsf"' "$ELSA_WORK" | grep -q 'category="100"'
grep '<prevent[^>]*pkg="com.google.android.gms"' "$ELSA_WORK" | grep -q 'mask="0000000000"'
grep '<prevent[^>]*pkg="com.google.android.gsf"' "$ELSA_WORK" | grep -q 'mask="0000000000"'
grep '<prevent[^>]*pkg="com.tencent.mm"' "$ELSA_WORK" | grep -q 'mask="0100000000"'
! grep -q '<cpuCtlWhiteList[^>]*pkg="com.tencent.mm"' "$ELSA_WORK"
grep '<item[^>]*name="dozeWhite"' "$ELSA_WORK" | grep -q 'whitePkg="com.google.android.gms#com.example.keep"'
grep '<item[^>]*name="hansKeepAlive"' "$ELSA_WORK" | grep -q 'whitePkg="com.google.android.gms"'

# 精准防火墙匹配：精确 UID 可删除，宽 UID 范围和无关应用必须保留。
GOOGLE_UIDS='10098 10159'
rule_is_google_related '-A fw_OUTPUT -m owner --uid-owner 10098 -j DROP'
rule_is_google_related '-A fw_OUTPUT -m comment --comment com.google.android.gms -j REJECT'
! rule_is_google_related '-A fw_OUTPUT -m owner --uid-owner 10000-19999 -j DROP'
! rule_is_google_related '-A fw_OUTPUT -m owner --uid-owner 10329 -j DROP'
! rule_is_google_related '-A fw_OUTPUT -p tcp --dport 443 -j REJECT'

# fail-safe：微信优化开启但 ROM 不再提供微信 prevent 条目时必须失败。
grep -v 'pkg="com.tencent.mm"' "$ROOT/tests/fixtures/elsa_sample.xml" > "$TMP_DIR/no_wechat.xml"
if build_elsa_patch "$TMP_DIR/no_wechat.xml" "$TMP_DIR/unsupported.xml"; then
    echo 'Expected unsupported ELSA layout to fail' >&2
    exit 1
fi

test ! -e "$ROOT/data/oplus/os/bpm/sys_elsa_config_list.xml"
grep -q '^version=v3.0$' "$ROOT/module.prop"

echo 'Module verification passed.'
