#!/system/bin/sh

MODDIR=${0%/*}
STATE_DIR="$MODDIR/state"
ELSA_TARGET="/data/oplus/os/bpm/sys_elsa_config_list.xml"

if [ -f "$STATE_DIR/.captured" ]; then
    original_value=$(cat "$STATE_DIR/google_restric_info" 2>/dev/null)
    if [ -z "$original_value" ] || [ "$original_value" = "null" ]; then
        settings delete secure google_restric_info > /dev/null 2>&1
    else
        settings put secure google_restric_info "$original_value"
    fi

    for package_name in com.google.android.gms com.google.android.gsf; do
        state_file="$STATE_DIR/whitelist_${package_name}"
        if [ -f "$state_file" ] && [ "$(cat "$state_file")" = "0" ]; then
            dumpsys deviceidle whitelist -"$package_name" > /dev/null 2>&1
        fi
    done
fi

if grep -F "$MODDIR/work/sys_elsa_config_list.xml $ELSA_TARGET " /proc/mounts > /dev/null 2>&1; then
    umount "$ELSA_TARGET" > /dev/null 2>&1
fi

exit 0
