#!/bin/sh
# v3 - Run on NEW LiBwrt/openwrt-6.x router AFTER clean sysupgrade (without keeping KWrt config)
# One-shot restore: safe mount, auto port mapping (lan1..lan3/wan), native Wi-Fi paths,
# offline nikki assets (ui/ruleset/providers/geodata) + TPROXY/CN-bypass/IPv6-relay tuning,
# full ZeroTier, root password, full 50-local.conf sysctl, and reboot.

set -e

echo "=== [1/7] Checking /dev/mmcblk0p21 mount ==="
EXIST_MNT=$(awk '$1=="/dev/mmcblk0p21" {print $2; exit}' /proc/mounts)
if [ -n "$EXIST_MNT" ]; then
  MNT="$EXIST_MNT"
  echo "  Already mounted at $MNT"
else
  MNT="/mnt/data"
  mkdir -p "$MNT"
  mount /dev/mmcblk0p21 "$MNT"
  echo "  Mounted at $MNT"
fi

SRC="${MNT}/migrate_kwrt"
if [ ! -d "$SRC/config" ]; then
  echo "ERROR: Backup directory $SRC/config not found!"
  exit 1
fi

echo "=== [2/7] Capturing new firmware native Wi-Fi hardware paths ==="
NEW_R0_PATH=$(uci -q get wireless.radio0.path || true)
NEW_R1_PATH=$(uci -q get wireless.radio1.path || true)
echo "  radio0=$NEW_R0_PATH | radio1=$NEW_R1_PATH"

echo "=== [3/7] Restoring core UCI configs ==="
for cfg in network wireless dhcp firewall nikki zerotier fstab ddns-aliyun cpufreq upnpd dropbear etherwake; do
  if [ -f "$SRC/config/$cfg" ]; then
    cp -a "$SRC/config/$cfg" "/etc/config/$cfg"
    echo "  + /etc/config/$cfg"
  fi
done

echo "=== [4/7] Restoring nikki subscriptions, profiles & geodata (offline boot ready) ==="
mkdir -p /etc/nikki/run
cp -a "$SRC/nikki/." /etc/nikki/ 2>/dev/null || true
if [ -d "$SRC/nikki_run" ]; then
  cp -a "$SRC/nikki_run/." /etc/nikki/run/ 2>/dev/null || true
fi

echo "=== [5/7] Restoring ZeroTier (identity, planet, controller, networks) ==="
if [ -d "$SRC/zerotier" ]; then
  mkdir -p /etc/zerotier
  cp -a "$SRC/zerotier/." /etc/zerotier/ 2>/dev/null || true
fi

echo "=== [6/7] Restoring SSH keys, root password & 4MB sysctl ==="
if [ -f "$SRC/authorized_keys" ]; then
  mkdir -p /etc/dropbear
  cp -a "$SRC/authorized_keys" /etc/dropbear/authorized_keys
fi
if [ -s "$SRC/root.shadow" ]; then
  ROOT_LINE=$(head -n 1 "$SRC/root.shadow")
  grep -v '^root:' /etc/shadow > /tmp/shadow.new
  { echo "$ROOT_LINE"; cat /tmp/shadow.new; } > /etc/shadow
  rm -f /tmp/shadow.new
  chmod 600 /etc/shadow
  echo "  + root password restored"
fi
cat << 'EOF' > /etc/sysctl.d/50-local.conf
net.nf_conntrack_max=65536
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.netdev_max_backlog=4096
net.core.netdev_budget=600
net.ipv4.tcp_rmem=4096 131072 4194304
net.ipv4.tcp_wmem=4096 65536 4194304
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq_codel
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_notsent_lowat=131072
net.ipv4.tcp_mtu_probing=1
net.ipv4.ip_local_port_range=10000 65535
EOF

echo "=== [7/7] Adapting port names, Wi-Fi paths, IPv6 relay, firewall & nikki TPROXY tuning ==="
# Adapt old eth0..eth3 to new DSA lan1..lan3 + wan
if ip link show lan1 >/dev/null 2>&1; then
  uci -q delete network.@device[0].ports || true
  for p in lan1 lan2 lan3 wan; do
    ip link show "$p" >/dev/null 2>&1 && uci add_list network.@device[0].ports="$p"
  done
  uci -q delete network.wan6.device || true
  uci set network.wan.disabled='1' 2>/dev/null || true
fi
uci set network.@device[0].promisc='0' 2>/dev/null || true
uci set network.globals.packet_steering='1' 2>/dev/null || true

# Enable IPv6 relay from lan6 -> nikki Wi-Fi bridge (for bypass router dual-stack)
if uci -q get network.lan6 >/dev/null 2>&1 && uci -q get dhcp.nikki >/dev/null 2>&1; then
  uci set dhcp.lan6=dhcp
  uci set dhcp.lan6.interface='lan6'
  uci set dhcp.lan6.master='1'
  uci set dhcp.lan6.ra='relay'
  uci set dhcp.lan6.dhcpv6='relay'
  uci set dhcp.lan6.ndp='relay'
  uci set dhcp.nikki.ra='relay'
  uci set dhcp.nikki.dhcpv6='relay'
  uci set dhcp.nikki.ndp='relay'
fi

# Restore native Wi-Fi paths
[ -n "$NEW_R0_PATH" ] && uci set wireless.radio0.path="$NEW_R0_PATH"
[ -n "$NEW_R1_PATH" ] && uci set wireless.radio1.path="$NEW_R1_PATH"

# Clean stale KWrt firewall includes & disable conflicting flow_offloading
for s in homeproxy_pre homeproxy_post passwall passwall_server; do
  uci -q delete "firewall.$s" || true
done
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'

# Allow SSH & LuCI admin access from Wi-Fi bridge (br-nikki / 192.168.66.1) and all LANs
uci -q delete dropbear.main.Interface || true
uci -q delete dropbear.@dropbear[0].Interface || true
uci set firewall.nikkizone.input='ACCEPT' 2>/dev/null || true

# Ensure CPU schedutil (1.2GHz idle -> 1.8GHz load boost) & nikki TPROXY + offline-safe local preference + CN bypass + fast CN DNS
uci set cpufreq.cpufreq.governor0='schedutil' 2>/dev/null || true
uci set cpufreq.cpufreq.minfreq0='1200000' 2>/dev/null || true
uci set cpufreq.cpufreq.maxfreq0='1800000' 2>/dev/null || true
if uci -q get nikki.proxy >/dev/null 2>&1; then
  uci set nikki.subscription.prefer='local' 2>/dev/null || true
  uci set nikki.proxy.tcp_mode='redirect'
  uci set nikki.proxy.udp_mode='tproxy'
  uci set nikki.mixin.tun_enabled='0'
  uci set nikki.proxy.bypass_china_mainland_ip='1'
  uci set nikki.proxy.bypass_china_mainland_ip6='1'
  uci set nikki.mixin.tcp_concurrent='1'
  uci set nikki.mixin.unified_delay='1'
  uci set nikki.mixin.dns_nameserver='1'
  uci set nikki.mixin.dns_nameserver_policy='1'
  uci set nikki.@nameserver[1].enabled='1' 2>/dev/null || true
  uci -q delete nikki.@nameserver[1].nameserver || true
  uci add_list nikki.@nameserver[1].nameserver='223.5.5.5'
  uci add_list nikki.@nameserver[1].nameserver='119.29.29.29'
  uci set nikki.@nameserver[2].enabled='1'
  uci -q delete nikki.@nameserver[2].nameserver || true
  uci add_list nikki.@nameserver[2].nameserver='223.5.5.5'
  uci add_list nikki.@nameserver[2].nameserver='119.29.29.29'
fi

uci commit

echo "=== Verification before reboot ==="
uci show network.@device[0]
echo "=== Restore complete! Rebooting in 5 seconds... ==="
sleep 5
reboot
