ColorOS GMS Extreme Fix (终极修复方案)
针对 ColorOS 16 深度定制的 GMS 推送修复模块。

🌟 模块简介
ColorOS 的后台管理系统（ELSA/OFreezer）对 GMS 极其不友好，即便放开自启动也难逃被冷冻或断连的命运。本模块通过直接修改系统核心策略文件 sys_elsa_config_list.xml，配合系统框架参数注入，实现 GMS 推送的秒级触达。
合并 Google拦截规则清理 https://github.com/CHIZI-0618/ColorOS-Google-Firewall-Fixer
🚀 核心功能
GMS 深度豁免：将 Google 服务框架（GMS/GSF）移出系统清理黑名单，并注入 bigDataCfg 的最高优先级白名单。

ELSA/OFreezer 破解：彻底放开 GMS 的后台掩码（Mask）限制，禁用针对 Google 服务的打盹模式（Doze）拦截。

框架开关解锁：自动注入 google_restric_info 0 参数，关闭系统框架对 GMS 持续持有 WakeLock 的限制。

社交软件调优（可选压制）：精准移除微信、QQ 的 CPU 调度白名单，强制其在后台进入缓存状态(无效)。

🛠 技术原理
挂载重定向：通过 KernelSU/Magisk 将修改后的 sys_elsa_config_list.xml 绑定挂载到 /data/oplus/os/bpm/。


📥 安装说明
确保设备已获取 KernelSU 或 Magisk 权限。

下载发布包 .zip 文件。

在管理器中刷入并重启。

重启后建议在终端运行 settings get secure google_restric_info 确认是否为 0。

⚠️ 免责声明
本模块涉及对系统底层功耗策略的深度修改，虽然在 OnePlus 15 上测试通过，但不同机型可能存在差异。刷入前请务必做好数据备份，如遇系统卡顿或掉电异常，请及时卸载模块。



