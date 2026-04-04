#!/system/bin/sh
# 定义模块路径
MODDIR=${0%/*}
TARGET_FILE="/data/oplus/os/bpm/sys_elsa_config_list.xml"

# 等待系统完全启动
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# --- [新增] 1. 解锁系统框架对 GMS 的隐藏限制 ---
# 这个命令能清空 HansPackageManager 中的 GMS 限制名单
settings put secure google_restric_info 0

# --- [优化] 2. 针对 BPM 目录的强制锁定挂载 ---
if [ -f "$MODDIR/data/oplus/os/bpm/sys_elsa_config_list.xml" ]; then
    # 挂载前先解除可能存在的 i 属性锁定
    chattr -i "$TARGET_FILE"
    
    # 执行绑定挂载
    mount --bind "$MODDIR/data/oplus/os/bpm/sys_elsa_config_list.xml" "$TARGET_FILE"

fi

# --- [新增] 3. 注入安卓原生 Doze (打盹) 白名单 ---
# 确保 GMS 拥有原生层面的不优化权限
dumpsys deviceidle whitelist +com.google.android.gms
dumpsys deviceidle whitelist +com.google.android.gsf

# --- [保留] 4. 执行原有的防火墙修复脚本 ---
if [ -f "$MODDIR/firewall_fix.sh" ]; then
    sh "$MODDIR/firewall_fix.sh" &
fi
