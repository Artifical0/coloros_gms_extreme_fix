# ColorOS GMS 推送平衡修复

> [!WARNING]
> **本项目已停止维护，不再更新，也不再处理 Issue。**
>
> 请改用后续项目 **[fcmfix-oneplus15-coloros16](https://github.com/Artifical0/fcmfix-oneplus15-coloros16)**（需要 Root + LSPosed），它针对一加 15 / ColorOS 16 的 FCM 推送问题持续维护：
>
> - 项目主页：https://github.com/Artifical0/fcmfix-oneplus15-coloros16
> - 下载最新版本：https://github.com/Artifical0/fcmfix-oneplus15-coloros16/releases/latest
>
> 迁移建议：先在模块管理器中停用并卸载本模块、重启，再按新项目 README 安装，避免两者同时修改系统推送策略。

面向 OnePlus 15 / ColorOS 16 的 Magisk、KernelSU、APatch 模块。目标是让 Google Play services 维持 FCM 长连接，同时让微信能够正常进入系统冻结，减少无意义的后台 CPU 消耗。

## v3.0 的变化

- 不再携带和覆盖整份 `sys_elsa_config_list.xml`。
- 每次开机复制当前 ROM 的 ELSA 文件，只修改 GMS、GSF 和微信的目标字段；格式不兼容或校验失败时拒绝挂载。
- GMS/GSF 保留 Android Doze 白名单和 ColorOS ELSA 白名单，`prevent mask` 设置为 `0000000000`。
- 微信不加入 Doze 白名单，移除 `cpuCtlWhiteList`，将 `prevent mask` 调整为平衡值 `0100000000`，保留 Alarm、网络恢复广播等 ROM 原有配置。
- 防火墙修复只删除能匹配 GMS、GSF、Play Store UID 或明确包名的 DROP/REJECT 规则；其他系统防火墙规则完全保留。

## 配置

刷入前或刷入后编辑模块目录中的 `config.conf`：

```ini
gms_fix=1
firewall_fix=1
wechat_optimize=1
```

修改后重启。若只需要 GMS 推送、不想修改微信策略，将 `wechat_optimize=0`。

## 安装

1. 确保设备已安装 Magisk、KernelSU 或 APatch。
2. 在模块管理器中刷入 Release ZIP。
3. 重启设备。
4. 不要在系统设置或第三方工具中对目标应用执行“强行停止/冻结”。Android 的 stopped 状态无法由 FCM 绕过。

## 验证

```sh
su -c 'settings get secure google_restric_info'
su -c 'dumpsys deviceidle whitelist | grep -E "google.android.gms|google.android.gsf"'
su -c 'cat /data/adb/modules/coloros_gms_extreme_fix/logs/service.log'
su -c 'cat /data/adb/modules/coloros_gms_extreme_fix/logs/firewall.log'
```

`google_restric_info` 应为 `0`。`service.log` 应显示动态 ELSA 补丁挂载成功；若 OTA 改变了 XML 结构，模块会记录失败并跳过挂载，不会用旧配置覆盖新 ROM。

锁屏 30–60 分钟分别测试 Nekogram、微信等 FCM 消息。微信的验收目标是“消息可及时唤醒，处理后能再次冻结”，不是让微信永久常驻。

## 限制与回退

- 模块不能让已经被 force-stop 的应用接收 FCM。
- 微信 APK 是否实际使用 FCM 由应用版本和服务器策略决定，本模块只保证系统侧通路。
- ColorOS OTA 后请检查 `service.log`。出现“不受支持”时，停用模块并提交新 ROM 的 ELSA 片段。
- 卸载脚本会恢复 v3 首次运行前记录的 `google_restric_info` 和 Doze 白名单状态；重启后防火墙与挂载状态也会由系统恢复。ROM 原始 XML 从未被改写。

防火墙修复思路来源：[CHIZI-0618/ColorOS-Google-Firewall-Fixer](https://github.com/CHIZI-0618/ColorOS-Google-Firewall-Fixer)。

## 免责声明

本模块会在 root 环境下调整系统运行时策略。请自行备份并承担刷机、耗电、兼容性风险。
