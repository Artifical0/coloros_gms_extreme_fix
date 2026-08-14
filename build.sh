#!/bin/sh
set -eu

version=$(sed -n 's/^version=//p' module.prop | head -n 1)
output="coloros_gms_fix_${version}.zip"

rm -f "$output"
zip -r -X "$output" \
    META-INF \
    action.sh \
    common.sh \
    config.conf \
    customize.sh \
    firewall_fix.sh \
    module.prop \
    service.sh \
    uninstall.sh

echo "Built $output"
