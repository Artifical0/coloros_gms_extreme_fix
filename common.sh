#!/system/bin/sh

MODDIR=${MODDIR:-${0%/*}}
CONFIG_FILE=${CONFIG_FILE:-"$MODDIR/config.conf"}
LOG_DIR=${LOG_DIR:-"$MODDIR/logs"}
SERVICE_LOG=${SERVICE_LOG:-"$LOG_DIR/service.log"}
FIREWALL_LOG=${FIREWALL_LOG:-"$LOG_DIR/firewall.log"}
ELSA_TARGET=${ELSA_TARGET:-"/data/oplus/os/bpm/sys_elsa_config_list.xml"}
ELSA_WORK=${ELSA_WORK:-"$MODDIR/work/sys_elsa_config_list.xml"}
STATE_DIR=${STATE_DIR:-"$MODDIR/state"}

ensure_runtime_dirs() {
    mkdir -p "$LOG_DIR" "${ELSA_WORK%/*}" "$STATE_DIR"
}

log_to() {
    local file="$1"
    shift
    ensure_runtime_dirs
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$file"
}

read_config_flag() {
    local key="$1"
    local default_value="$2"
    local value=""

    if [ -f "$CONFIG_FILE" ]; then
        value=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\([01]\)[[:space:]]*$/\1/p" "$CONFIG_FILE" | tail -n 1)
    fi

    case "$value" in
        0|1) echo "$value" ;;
        *) echo "$default_value" ;;
    esac
}

load_config() {
    GMS_FIX=$(read_config_flag gms_fix 1)
    FIREWALL_FIX=$(read_config_flag firewall_fix 1)
    WECHAT_OPTIMIZE=$(read_config_flag wechat_optimize 1)
    export GMS_FIX FIREWALL_FIX WECHAT_OPTIMIZE
}

capture_runtime_state() {
    ensure_runtime_dirs
    [ -f "$STATE_DIR/.captured" ] && return 0

    settings get secure google_restric_info > "$STATE_DIR/google_restric_info" 2>/dev/null || \
        echo null > "$STATE_DIR/google_restric_info"

    for package_name in com.google.android.gms com.google.android.gsf; do
        if dumpsys deviceidle whitelist 2>/dev/null | grep -q "$package_name"; then
            echo 1 > "$STATE_DIR/whitelist_${package_name}"
        else
            echo 0 > "$STATE_DIR/whitelist_${package_name}"
        fi
    done

    : > "$STATE_DIR/.captured"
}

insert_before_first() {
    local file="$1"
    local needle="$2"
    local new_line="$3"
    local temp_file="${file}.insert.$$"

    awk -v needle="$needle" -v new_line="$new_line" '
        !inserted && index($0, needle) {
            print new_line
            inserted = 1
        }
        { print }
        END { if (!inserted) exit 42 }
    ' "$file" > "$temp_file"
    local result=$?

    if [ "$result" -ne 0 ]; then
        rm -f "$temp_file"
        return "$result"
    fi

    mv -f "$temp_file" "$file"
}

ensure_white_pkg() {
    local file="$1"
    local package_name="$2"

    if grep -q "<whitePkg[^>]*name=\"${package_name}\"" "$file"; then
        sed -i "/<whitePkg[^>]*name=\"${package_name}\"/ s/category=\"[^\"]*\"/category=\"100\"/" "$file"
    else
        insert_before_first "$file" '<whitePkg ' "        <whitePkg name=\"${package_name}\" category=\"100\"/>" || return 1
    fi

    grep "<whitePkg[^>]*name=\"${package_name}\"" "$file" | grep -q 'category="100"'
}

ensure_prevent_mask() {
    local file="$1"
    local package_name="$2"
    local mask="$3"
    local require_existing="${4:-0}"

    if grep -q "<prevent[^>]*pkg=\"${package_name}\"" "$file"; then
        sed -i "/<prevent[^>]*pkg=\"${package_name}\"/ s/mask=\"[^\"]*\"/mask=\"${mask}\"/" "$file"
    elif [ "$require_existing" = "1" ]; then
        return 1
    else
        insert_before_first "$file" '<prevent ' "    <prevent scene=\"110\" pkg=\"${package_name}\" mask=\"${mask}\"/>" || return 1
    fi

    grep "<prevent[^>]*pkg=\"${package_name}\"" "$file" | grep -q "mask=\"${mask}\""
}

ensure_big_data_whitelist() {
    local file="$1"
    local item_name="$2"
    local package_name="$3"

    grep -q '<bigDataCfg>' "$file" || return 1

    if grep -q "<item[^>]*name=\"${item_name}\"" "$file"; then
        if grep "<item[^>]*name=\"${item_name}\"" "$file" | grep -q "whitePkg=\"[^\"]*${package_name}"; then
            return 0
        fi

        if grep "<item[^>]*name=\"${item_name}\"" "$file" | grep -q 'whitePkg=""'; then
            sed -i "/<item[^>]*name=\"${item_name}\"/ s/whitePkg=\"\"/whitePkg=\"${package_name}\"/" "$file"
        elif grep "<item[^>]*name=\"${item_name}\"" "$file" | grep -q 'whitePkg="'; then
            sed -i "/<item[^>]*name=\"${item_name}\"/ s/whitePkg=\"/whitePkg=\"${package_name}#/" "$file"
        else
            return 1
        fi
    else
        insert_before_first "$file" '</bigDataCfg>' "        <item name=\"${item_name}\" preVersion=\"true\" comVersion=\"false\" whitePkg=\"${package_name}\" blackPkg=\"\"/>" || return 1
    fi

    grep "<item[^>]*name=\"${item_name}\"" "$file" | grep -q "whitePkg=\"[^\"]*${package_name}"
}

validate_xml_shape() {
    local file="$1"
    [ -s "$file" ] || return 1
    grep -q '^<?xml ' "$file" || return 1
    grep -q '<filter-conf>' "$file" || return 1
    grep -q '</filter-conf>' "$file" || return 1
}

build_elsa_patch() {
    local source_file="$1"
    local output_file="$2"

    [ -f "$source_file" ] || return 1
    ensure_runtime_dirs
    cp -af "$source_file" "$output_file" || return 1
    validate_xml_shape "$output_file" || return 1

    ensure_white_pkg "$output_file" com.google.android.gms || return 1
    ensure_white_pkg "$output_file" com.google.android.gsf || return 1
    ensure_prevent_mask "$output_file" com.google.android.gms 0000000000 || return 1
    ensure_prevent_mask "$output_file" com.google.android.gsf 0000000000 || return 1

    # bigDataCfg 在不同 OTA 中可能变化；缺失时只跳过这项增强，不覆盖 ROM 文件结构。
    ensure_big_data_whitelist "$output_file" dozeWhite com.google.android.gms || \
        log_to "$SERVICE_LOG" "未找到兼容的 dozeWhite 项，已跳过该项"
    ensure_big_data_whitelist "$output_file" hansKeepAlive com.google.android.gms || \
        log_to "$SERVICE_LOG" "未找到兼容的 hansKeepAlive 项，已跳过该项"

    if [ "$WECHAT_OPTIMIZE" = "1" ]; then
        # 微信条目必须来自当前 ROM；找不到时拒绝挂载，避免猜测新 OTA 的格式。
        ensure_prevent_mask "$output_file" com.tencent.mm 0100000000 1 || return 1
        sed -i '/<cpuCtlWhiteList[^>]*pkg="com\.tencent\.mm"[^>]*\/>/d' "$output_file"
        grep "<prevent[^>]*pkg=\"com.tencent.mm\"" "$output_file" | grep -q 'mask="0100000000"' || return 1
        if grep -q '<cpuCtlWhiteList[^>]*pkg="com\.tencent\.mm"' "$output_file"; then
            return 1
        fi
    fi

    validate_xml_shape "$output_file"
}

apply_elsa_patch() {
    if [ ! -f "$ELSA_TARGET" ]; then
        log_to "$SERVICE_LOG" "未找到 ELSA 配置：$ELSA_TARGET，跳过挂载"
        return 1
    fi

    if grep -F " $ELSA_TARGET " /proc/mounts > /dev/null 2>&1; then
        log_to "$SERVICE_LOG" "ELSA 目标已被其他挂载占用，跳过以避免覆盖"
        return 1
    fi

    if ! build_elsa_patch "$ELSA_TARGET" "$ELSA_WORK"; then
        rm -f "$ELSA_WORK"
        log_to "$SERVICE_LOG" "ELSA 格式不受支持或补丁校验失败，未执行挂载"
        return 1
    fi

    if mount --bind "$ELSA_WORK" "$ELSA_TARGET"; then
        log_to "$SERVICE_LOG" "已基于当前 ROM 动态修补并挂载 ELSA 配置"
        return 0
    fi

    log_to "$SERVICE_LOG" "ELSA bind mount 失败"
    return 1
}

append_unique_uid() {
    local uid="$1"
    case " $GOOGLE_UIDS " in
        *" $uid "*) ;;
        *) GOOGLE_UIDS="$GOOGLE_UIDS $uid" ;;
    esac
}

resolve_google_uids() {
    local packages="com.google.android.gms com.google.android.gsf com.android.vending"
    local users
    GOOGLE_UIDS=""
    users=$(cmd user list 2>/dev/null | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p')
    [ -n "$users" ] || users="0"

    for package_name in $packages; do
        local app_id
        app_id=$(dumpsys package "$package_name" 2>/dev/null | sed -n 's/^[[:space:]]*userId=\([0-9][0-9]*\).*/\1/p' | head -n 1)
        [ -n "$app_id" ] || continue

        # dumpsys 的 userId 对普通应用是 user 0 UID；保留 appId 后为每个用户计算实际 UID。
        app_id=$((app_id % 100000))
        for user_id in $users; do
            append_unique_uid $((user_id * 100000 + app_id))
        done
    done

    GOOGLE_UIDS=$(echo "$GOOGLE_UIDS")
    export GOOGLE_UIDS
    [ -n "$GOOGLE_UIDS" ]
}

uid_spec_contains_google_uid() {
    local spec="$1"
    local start_uid end_uid uid
    spec=$(echo "$spec" | tr ':' '-')

    case "$spec" in
        *-*)
            start_uid=${spec%%-*}
            end_uid=${spec##*-}
            ;;
        *)
            start_uid="$spec"
            end_uid="$spec"
            ;;
    esac

    case "$start_uid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$end_uid" in
        ''|*[!0-9]*) return 1 ;;
    esac

    for uid in $GOOGLE_UIDS; do
        # 只接受精确 UID 或 start=end 的单 UID 范围；绝不删除覆盖其他应用的宽范围规则。
        if [ "$start_uid" = "$uid" ] && [ "$end_uid" = "$uid" ]; then
            return 0
        fi
    done
    return 1
}

rule_is_google_related() {
    local rule="$1"
    local uid_spec

    case "$rule" in
        *com.google.android.gms*|*com.google.android.gsf*|*com.android.vending*) return 0 ;;
    esac

    uid_spec=$(echo "$rule" | sed -n 's/.*--uid-owner[[:space:]]\([^[:space:]]*\).*/\1/p')
    [ -n "$uid_spec" ] || return 1
    uid_spec_contains_google_uid "$uid_spec"
}

remove_google_block_rules() {
    local table="${1:-filter}"
    local chain="$2"
    local proto="${3:-ipv4}"
    local command rules_file matches_file line rule_number deleted_count

    case "$proto" in
        ipv4) command=iptables ;;
        ipv6) command=ip6tables ;;
        *) log_to "$FIREWALL_LOG" "不支持的协议：$proto"; return 1 ;;
    esac

    command -v "$command" > /dev/null 2>&1 || {
        log_to "$FIREWALL_LOG" "跳过 $proto：$command 不存在"
        return 0
    }

    rules_file="$LOG_DIR/${proto}_${chain}_rules.$$"
    matches_file="$LOG_DIR/${proto}_${chain}_matches.$$"
    if ! "$command" -t "$table" -S "$chain" > "$rules_file" 2>/dev/null; then
        rm -f "$rules_file" "$matches_file"
        log_to "$FIREWALL_LOG" "跳过 $proto/$chain：链不存在"
        return 0
    fi

    rule_number=0
    : > "$matches_file"
    while IFS= read -r line; do
        case "$line" in
            "-A $chain "*) rule_number=$((rule_number + 1)) ;;
            *) continue ;;
        esac

        case " $line " in
            *' -j DROP '*|*' -j REJECT '*) ;;
            *) continue ;;
        esac

        if rule_is_google_related "$line"; then
            echo "$rule_number" >> "$matches_file"
            log_to "$FIREWALL_LOG" "匹配 $proto/$chain #$rule_number：$line"
        fi
    done < "$rules_file"

    deleted_count=0
    for rule_number in $(sort -rn "$matches_file"); do
        if "$command" -t "$table" -D "$chain" "$rule_number" 2>/dev/null; then
            deleted_count=$((deleted_count + 1))
        else
            log_to "$FIREWALL_LOG" "删除失败 $proto/$chain #$rule_number"
        fi
    done

    rm -f "$rules_file" "$matches_file"
    log_to "$FIREWALL_LOG" "$proto/$chain 仅删除 Google 相关规则 $deleted_count 条"
}
