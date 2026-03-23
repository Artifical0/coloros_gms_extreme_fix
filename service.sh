#!/system/bin/sh
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
# 针对 BPM 目录的特殊性，使用强制绑定挂载
mount --bind /data/adb/modules/coloros_gms_extreme_fix/data/oplus/os/bpm/sys_elsa_config_list.xml /data/oplus/os/bpm/sys_elsa_config_list.xml
