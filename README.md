# JDCloud AX1800 Pro (亚瑟 RE-SS-01) 满血 NSS 自编译固件仓库

基于 **`LiBwrt/openwrt-6.x` (`25.12-nss`)** 的 GitHub Actions 自动编译仓库，专为 **京东云亚瑟 AX1800 Pro（128G eMMC / 512MB 原装内存）** 定制。

## 核心特性
- **满血高通 NSS 硬件加速**：有线 ECM + 无线 `ath11k` Wi-Fi Offload（严格启用 `ATH11K_MEM_PROFILE_512M`，适配 512MB 原装内存防 OOM）。
- **1.8GHz 四核全频率**：基于 `ipq6018-cp-cpu.dtsi` 完整解锁 1.8GHz OPP。
- **网页直接升级兼容**：`diy-part2.sh` 自动为 `jdcloud_re-ss-01` 追加 `SUPPORTED_DEVICES += jdcloud,ax1800-pro`，支持从旧 KWrt 网页直接升级。
- **精简稳定**：使用轻量 `uhttpd` 替代重型 `nginx`，内置 `nikki (mihomo)`、`zerotier`、`ttyd`、`ddns-aliyun`、`upnp`、`cpufreq`、`argon` 主题与 4MB `rmem/wmem` 网络调优。
- **内置一键在线升级命令 `jb-upgrade`**：后续版本直接调用 GitHub Releases API 校验 SHA256 并保留配置无感升级。

## 使用流程

### 1. 触发 GitHub Actions 编译
在 GitHub 仓库的 **Actions** 页面点击 **Build JDCloud AX1800 Pro (NSS 512M)** → **Run workflow**，约 40–60 分钟后固件自动发布到 **Releases**。

### 2. 首次从 KWrt 平滑迁移（不丢业务配置、不带入旧垃圾）
1. 在当前 KWrt 路由器上运行 `scripts/migrate_backup.sh`，将干净的业务配置（`network`/`wireless`/`dhcp`/`firewall`/`nikki` 订阅/`zerotier`/`fstab`）备份到 `/mnt/data/migrate_kwrt/`（位于 `mmcblk0p21`，刷机不会格式化）。
2. 在 LuCI 网页上传编译好的 `*-jdcloud_re-ss-01-squashfs-sysupgrade.bin`，**取消勾选“保留配置”**进行首次干净刷入。
3. 刷完重启后，通过网线/默认 IP 登录新固件，执行：
   ```sh
   mount /dev/mmcblk0p21 /mnt/data
   sh /mnt/data/migrate_kwrt/migrate_restore.sh
   ```
   路由器自动还原全部配置并重启（原旁路由 IP `192.168.31.222`、Wi-Fi `Kwrt_5G_cz`、`nikki` 代理、ZeroTier、`/mnt/data` 全部恢复）。

### 3. 后续无感升级（同源固件）
- **网页升级**：LuCI → 系统 → 备份与升级 → 上传新 `sysupgrade.bin` 并**勾选“保留配置”**。
- **命令行一键升级**：SSH 登录路由器直接执行：
  ```sh
  jb-upgrade
  ```
  （若直连 GitHub 慢，可加代理前缀：`jb-upgrade https://gh-proxy.com/`）
