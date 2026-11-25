#!/bin/sh
# v3 - Run on CURRENT KWrt router BEFORE flashing LiBwrt/openwrt-6.x
# Backs up clean business configs + nikki offline assets (ui/ruleset/providers/geodata)
# + full ZeroTier (planet/controller/identity) + root shadow

set -e

EXIST_MNT=$(awk '$1=="/dev/mmcblk0p21" {print $2; exit}' /proc/mounts)
if [ -n "$EXIST_MNT" ]; then
  MNT="$EXIST_MNT"
else
  MNT="/mnt/data"
  mkdir -p "$MNT"
  mount /dev/mmcblk0p21 "$MNT"
fi

DST="${MNT}/migrate_kwrt"
mkdir -p "$DST/config" "$DST/nikki" "$DST/nikki_run" "$DST/zerotier" "$DST/sysctl.d"

echo "=== [1/5] Backing up core UCI configs ==="
for cfg in network wireless dhcp firewall nikki zerotier fstab ddns-aliyun cpufreq upnpd dropbear; do
  if [ -f "/etc/config/$cfg" ]; then
    cp -a "/etc/config/$cfg" "$DST/config/"
    echo "  + /etc/config/$cfg"
  fi
done

echo "=== [2/5] Backing up nikki profiles, subscriptions, mixin & offline assets ==="
for item in subscriptions profiles mixin.yaml; do
  if [ -e "/etc/nikki/$item" ]; then
    cp -a "/etc/nikki/$item" "$DST/nikki/"
    echo "  + /etc/nikki/$item"
  fi
done
for geo in geoip.metadb GeoSite.dat geosite.dat geoip.dat ASN.mmdb; do
  if [ -f "/etc/nikki/run/$geo" ]; then
    cp -a "/etc/nikki/run/$geo" "$DST/nikki_run/"
    echo "  + /etc/nikki/run/$geo"
  fi
done
for dir in ui ruleset providers; do
  if [ -d "/etc/nikki/run/$dir" ]; then
    rm -rf "$DST/nikki_run/$dir"
    cp -a "/etc/nikki/run/$dir" "$DST/nikki_run/"
    echo "  + /etc/nikki/run/$dir/"
  fi
done

echo "=== [3/5] Backing up full ZeroTier (identity, planet, controller, networks) ==="
if [ -d "/etc/zerotier" ]; then
  cp -a /etc/zerotier/. "$DST/zerotier/" 2>/dev/null || true
  rm -f "$DST/zerotier/zerotier-one.pid" "$DST/zerotier/zerotier-one.port" "$DST/zerotier/metrics.prom"
fi

echo "=== [4/5] Backing up sysctl, SSH keys & root shadow ==="
[ -f /etc/sysctl.d/50-local.conf ] && cp -a /etc/sysctl.d/50-local.conf "$DST/sysctl.d/"
[ -f /etc/dropbear/authorized_keys ] && cp -a /etc/dropbear/authorized_keys "$DST/"
grep '^root:' /etc/shadow > "$DST/root.shadow" 2>/dev/null || true

echo "=== [5/5] Backup complete! Saved in $DST ==="
ls -lh "$DST" "$DST/nikki_run" 2>/dev/null
