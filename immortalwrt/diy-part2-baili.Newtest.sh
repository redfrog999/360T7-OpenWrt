#!/bin/bash

echo "开始执行【万里版】逻辑对齐重构脚本……"
echo "========================="

# --- 0. 基础环境清理与物理去瘀 ---
# 修改默认IP
sed -i 's/192.168.6.1/192.168.12.1/g' package/base-files/files/bin/config_generate

# 彻底清理 PassWall、老旧 OpenClash 和残留核心库 (防止逻辑冲突)
rm -rf feeds/packages/net/{xray*,v2ray*,sing-box,hysteria*,shadowsocks*,trojan*,clash*}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/passwall-packages

# --- 1. 添加主题
rm -rf feeds/luci/themes/luci-theme-argon
# git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth 1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon package/luci-theme-argon
# git clone --depth=1 -b master https://github.com/sirpdboy/luci-theme-kucat package/luci-theme-kucat
git clone --depth=1 -b master https://github.com/NicolasMe9907/luci-theme-kucat package/luci-theme-kucat
# git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-kucat-config package/luci-app-kucat-config
git clone --depth=1 -b main https://github.com/NicolasMe9907/luci-app-advancedplus  package/luci-app-advancedplus

git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora package/luci-theme-aurora
echo "CONFIG_PACKAGE_luci-theme-aurora=y" >> .config

# 取消自添加主题的默认设置
find package/luci-theme-*/* -type f -print | grep '/root/etc/uci-defaults/' | while IFS= read -r file; do
	sed -i '/set luci.main.mediaurlbase/d' "$file"
done

# 设置默认主题
default_theme='kucat'
sed -i "s/bootstrap/$default_theme/g" feeds/luci/modules/luci-base/root/etc/config/luci

# 強制給予 uci-defaults 腳本執行權限，防止雲端編譯權限丟失
chmod +x files/etc/uci-defaults/99_physical_sovereignty

# --- 2. 插件与核心物料注入 (逻辑对齐) ---

# 克隆 Nikki (基于 Mihomo)
rm -rf feeds/luci/applications/luci-app-nikki
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# 克隆最新版 OpenClash 并强制对齐 dnsmasq-full
find ./ -name "luci-app-openclash" -type d -exec rm -rf {} +
git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash
sed -i 's/dnsmasq/dnsmasq-full/g' package/luci-app-openclash/luci-app-openclash/Makefile

# =========================================================
# 🛠️ 暴力重组与逻辑对齐：百里 2.3GHz 咆哮版终极补丁
# =========================================================

# 1. 针对 Rustc 源码的物理手术 (解决图 13 挂死)
RUST_FILE="rustc-1.90.0-src.tar.xz"
RUST_URL="https://github.com/redfrog999/JDCloud-AX6000/releases/download/rustc_1.9.0/$RUST_FILE"

mkdir -p dl/tmp_rust
wget -qO dl/$RUST_FILE "$RUST_URL"
# 手动解压并注入修复逻辑
tar -xJf dl/$RUST_FILE -C dl/tmp_rust
find dl/tmp_rust -name ".cargo-checksum.json" -delete
find dl/tmp_rust -name "Cargo.toml.orig" -exec touch {} +
# 物理封包并更新系统 Hash
cd dl/tmp_rust && tar -cJf ../$RUST_FILE * && cd ../..
rm -rf dl/tmp_rust

RUST_MAKEFILE=$(find feeds/packages/lang/rust -name "Makefile")
if [ -n "$RUST_MAKEFILE" ]; then
    NEW_HASH=$(sha256sum dl/$RUST_FILE | awk '{print $1}')
    sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$RUST_MAKEFILE"
fi

# 2. 依赖名精准对齐 (解决 dnsmasq-full-full 报错)
find package/ feeds/ -name Makefile -exec sed -i 's/dnsmasq-full-full/dnsmasq-full/g' {} +

# 3. 锁定生命线包 (确保 SmartDNS、Ruby、SafeXcel 正常)
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config
echo "CONFIG_PACKAGE_smartdns=y" >> .config
echo "CONFIG_PACKAGE_ruby=y" >> .config
echo "CONFIG_PACKAGE_ruby-yaml=y" >> .config
echo "CONFIG_PACKAGE_kmod-crypto-user=y" >> .config

# 4. sbwml 版 Argon 皮肤物理注入
rm -rf feeds/luci/themes/luci-theme-argon package/luci-theme-argon
git clone --depth 1 -b openwrt-24.10 https://github.com/sbwml/luci-theme-argon package/luci-theme-argon

# 5. 编译环境闭环：强制离线编译
export CARGO_NET_OFFLINE=true
export CARGO_GENERATE_LOCKFILE=false
rm -rf tmp/.packageinfo

# --- 3. 硬件性能加速与指令集对齐 (SafeXcel & A53) ---

# 唤醒 SafeXcel 硬件引擎编译参数
sed -i 's/-Os -pipe/-O2 -pipe -march=armv8-a+crc+crypto -mtune=cortex-a53/g' include/target.mk
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+crc+crypto/g' include/target.mk

# 锁定高性能模式与硬解模块默认加载
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_kmod-crypto-aes=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
EOF

# --- 4. 系统内核优化 (全量对齐) ---

# 统一注入 sysctl 参数 (BBR + 调度优化)
cat >> package/base-files/files/etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
kernel.sched_latency_ns=8000000
net.core.netdev_budget=1000
vm.vfs_cache_pressure=40
vm.min_free_kbytes=20480
EOF

# 物理 HNAT (PPE) 开启逻辑注入
sed -i '/exit 0/i \
sysctl -w net.netfilter.nf_flow_table_hw=1 \
for i in /sys/devices/system/cpu/cpufreq/policy*; do echo performance > "$i/scaling_governor"; done \
modprobe crypto_safexcel 2>/dev/null' package/base-files/files/etc/rc.local

# --- 5. 分机型适配与配置固化 ---

# 根据 .config 自动检测并删除冗余监控插件 (清理内耗)
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_wrtbwmon=y/CONFIG_PACKAGE_wrtbwmon=n/g' .config

# 拷贝自定义 DIY 目录 (如果存在)
[ -d "${GITHUB_WORKSPACE}/immortalwrt/diy" ] && cp -Rf ${GITHUB_WORKSPACE}/immortalwrt/diy/* .

# 最后的逻辑收束
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

echo "========================="
echo "✅ DIY2 逻辑重组完成，等待咆哮！"
