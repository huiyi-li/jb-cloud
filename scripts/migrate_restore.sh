#!/bin/sh
# Run on NEW LiBwrt/openwrt-6.x router AFTER first clean sysupgrade (without keeping KWrt config)
# Restores clean business configs from /mnt/data/migrate_kwrt/

set -e

# Ensure /mnt/data (mmcblk0p21) is mounted cleanly without duplicate mounts
if ! grep -qs " /mnt/data " /proc/mounts; then
  EXIST_MNT=$(awk '$1=="/dev/mmcblk0p21" {print $2; exit}' /proc/mounts)
  if [ -n "$EXIST_MNT" ]; then
    echo "INFO: /dev/mmcblk0p21 already mounted at $EXIST_MNT, using it."
    SRC="${EXIST_MNT}/migrate_kwrt"
  else
    mkdir -p /mnt/data
    mount /dev/mmcblk0p21 /mnt/data
    SRC="/mnt/data/migrate_kwrt"
  fi
else
  SRC="/mnt/data/migrate_kwrt"
fi

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

echo "=== Ensuring clean network port names, firewall & performance settings ==="
if ip link show lan1 >/dev/null 2>&1; then
  echo "Detected new DSA/LiBwrt port names (lan1..lan3, wan); updating br-lan ports..."
  uci -q delete network.@device[0].ports || true
  for p in lan1 lan2 lan3 wan; do
    ip link show "$p" >/dev/null 2>&1 && uci add_list network.@device[0].ports="$p"
  done
fi
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci set network.@device[0].promisc='0' 2>/dev/null || true
uci set cpufreq.cpufreq.governor0='performance' 2>/dev/null || true
uci commit

echo "=== Restore complete! Rebooting in 5 seconds... ==="
sleep 5
reboot
