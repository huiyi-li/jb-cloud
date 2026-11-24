#!/bin/sh
# Run on NEW LiBwrt/openwrt-6.x router AFTER first clean sysupgrade (without keeping KWrt config)
# Restores clean business configs from /mnt/data/migrate_kwrt/

set -e

# Ensure /mnt/data (mmcblk0p21) is mounted
if ! mountpoint -q /mnt/data; then
  mkdir -p /mnt/data
  mount /dev/mmcblk0p21 /mnt/data
fi

SRC="/mnt/data/migrate_kwrt"
if [ ! -d "$SRC/config" ]; then
  echo "ERROR: Backup directory $SRC/config not found!"
  exit 1
fi

echo "=== Restoring core UCI configs ==="
for cfg in network wireless dhcp firewall nikki zerotier fstab cpufreq upnpd dropbear; do
  if [ -f "$SRC/config/$cfg" ]; then
    cp -a "$SRC/config/$cfg" "/etc/config/$cfg"
    echo "  + /etc/config/$cfg"
  fi
done

echo "=== Restoring nikki subscriptions & profiles ==="
mkdir -p /etc/nikki
cp -a "$SRC/nikki/"* /etc/nikki/ 2>/dev/null || true

echo "=== Restoring ZeroTier identity ==="
if [ -d "$SRC/zerotier" ]; then
  mkdir -p /etc/zerotier
  cp -a "$SRC/zerotier/"* /etc/zerotier/ 2>/dev/null || true
fi

echo "=== Restoring sysctl & SSH keys ==="
[ -f "$SRC/sysctl.d/50-local.conf" ] && cp -a "$SRC/sysctl.d/50-local.conf" /etc/sysctl.d/50-local.conf
[ -f "$SRC/authorized_keys" ] && mkdir -p /etc/dropbear && cp -a "$SRC/authorized_keys" /etc/dropbear/authorized_keys

echo "=== Ensuring clean firewall & performance settings ==="
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci set network.@device[0].promisc='0' 2>/dev/null || true
uci set cpufreq.cpufreq.governor0='performance' 2>/dev/null || true
uci commit

echo "=== Restore complete! Rebooting in 5 seconds... ==="
sleep 5
reboot
