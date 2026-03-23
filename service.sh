#!/system/bin/sh
# 定义模块路径（Magisk 建议在 service.sh 中手动获取路径，避免变量丢失）
MODDIR=${0%/*}

# 等待系统完全启动
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# 1. 针对 BPM 目录的强制绑定挂载
# 确保目标文件存在再挂载，防止挂载到空路径导致系统异常
if [ -f "$MODDIR/data/oplus/os/bpm/sys_elsa_config_list.xml" ]; then
    mount --bind "$MODDIR/data/oplus/os/bpm/sys_elsa_config_list.xml" /data/oplus/os/bpm/sys_elsa_config_list.xml
fi

# 2. 执行合并进来的防火墙修复脚本
# 使用绝对路径执行，并确保后台运行
if [ -f "$MODDIR/firewall_fix.sh" ]; then
    sh "$MODDIR/firewall_fix.sh" &
fi
