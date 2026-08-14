ui_print "- 安装 ColorOS GMS 推送平衡修复 v3.0"
ui_print "- ELSA 将在开机时基于当前 ROM 动态修补"
ui_print "- 微信优化可在 config.conf 中关闭"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/firewall_fix.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/common.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
