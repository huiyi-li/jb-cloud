#!/bin/bash
set -e

echo "=== [diy-part2] Patching SUPPORTED_DEVICES for KWrt web sysupgrade compatibility ==="
IPQ60XX_MK="target/linux/qualcommax/image/ipq60xx.mk"
if grep -q "define Device/jdcloud_re-ss-01" "$IPQ60XX_MK"; then
  if ! grep -A 12 "define Device/jdcloud_re-ss-01" "$IPQ60XX_MK" | grep -q "jdcloud,ax1800-pro"; then
    sed -i '/define Device\/jdcloud_re-ss-01/,/endef/ {
      /DEVICE_PACKAGES := ipq-wifi-jdcloud_re-ss-01/a\	SUPPORTED_DEVICES += jdcloud,ax1800-pro
    }' "$IPQ60XX_MK"
  fi
fi

echo "=== [diy-part2] Verifying jdcloud_re-ss-01 device block ==="
sed -n '/define Device\/jdcloud_re-ss-01/,/endef/p' "$IPQ60XX_MK"

echo "=== [diy-part2] Verifying 1.8GHz OPP in ipq6018-cp-cpu.dtsi ==="
grep -E "opp-1800000000" target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-cp-cpu.dtsi || echo "WARNING: opp-1800000000 not found!"

echo "=== [diy-part2] Setting default timezone & hostname ==="
sed -i "s/hostname='OpenWrt'/hostname='JB-AX1800'/g" package/base-files/files/bin/config_generate
sed -i "s/timezone='UTC'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
if ! grep -q "zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate; then
  sed -i "/timezone='CST-8'/a\\\t\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
fi
