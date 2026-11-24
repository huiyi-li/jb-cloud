#!/bin/bash
set -e

echo "=== [diy-part1] Adding OpenWrt-nikki feed ==="
if ! grep -q "nikkinikki-org/OpenWrt-nikki" feeds.conf.default; then
  echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> feeds.conf.default
fi

cat feeds.conf.default
