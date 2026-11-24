#!/bin/sh
# Run on CURRENT KWrt router BEFORE flashing LiBwrt/openwrt-6.x
# Backs up clean business configs (excluding KWrt-specific nginx/quickstart/istore) to /mnt/data/migrate_kwrt/

set -e

DST="/mnt/data/migrate_kwrt"
mkdir -p "$DST/config" "$DST/nikki" "$DST/zerotier" "$DST/sysctl.d"

echo "=== Backing up core UCI configs ==="
for cfg in network wireless dhcp firewall nikki zerotier fstab ddns-aliyun cpufreq upnpd dropbear; do
  if [ -f "/etc/config/$cfg" ]; then
    cp -a "/etc/config/$cfg" "$DST/config/"
    echo "  + /etc/config/$cfg"
  fi
done

echo "=== Backing up nikki profiles, subscriptions & mixin ==="
for item in subscriptions profiles mixin.yaml; do
  if [ -e "/etc/nikki/$item" ]; then
    cp -a "/etc/nikki/$item" "$DST/nikki/"
    echo "  + /etc/nikki/$item"
  fi
done

echo "=== Backing up ZeroTier identity & networks ==="
if [ -d "/etc/zerotier" ]; then
  cp -a /etc/zerotier/* "$DST/zerotier/" 2>/dev/null || true
fi
if [ -d "/var/lib/zerotier-one" ]; then
  mkdir -p "$DST/zerotier_var"
  cp -a /var/lib/zerotier-one/identity.* /var/lib/zerotier-one/planet /var/lib/zerotier-one/networks.d "$DST/zerotier_var/" 2>/dev/null || true
fi

echo "=== Backing up sysctl & root password/ssh keys ==="
cp -a /etc/sysctl.d/50-local.conf "$DST/sysctl.d/" 2>/dev/null || true
cp -a /etc/dropbear/authorized_keys "$DST/" 2>/dev/null || true
grep '^root:' /etc/shadow > "$DST/root.shadow" 2>/dev/null || true

echo "=== Backup complete! Saved in $DST ==="
ls -la "$DST"
