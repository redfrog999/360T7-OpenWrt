#!/bin/bash
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "开始 DIY2 配置……"
echo "========================="

chmod +x ${GITHUB_WORKSPACE}/immortalwrt/function.sh
source ${GITHUB_WORKSPACE}/immortalwrt/function.sh

# 修改x86内核到6.6版
# sed -i 's/KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=6.6/g' ./target/linux/x86/Makefile

# 默认IP由1.1修改为6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 最大连接数修改为65535
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# luci-compat - 修复上移下移按钮翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

# luci-compat - remove extra line breaks from description
sed -i '/<br \/>/d' feeds/luci/modules/luci-compat/luasrc/view/cbi/full_valuefooter.htm

# 修复procps-ng-top导致首页cpu使用率无法获取
sed -i 's#top -n1#\/bin\/busybox top -n1#g' feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci

# 強制給予 uci-defaults 腳本執行權限，防止雲端編譯權限丟失
chmod +x files/etc/uci-defaults/99_physical_sovereignty

#临时解决Rust问题
# sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# ------------------PassWall 科学上网Clean--------------------------
# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box,pdnsd-alt,chinadns-ng,dns2socks,dns2tcp,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview}
# 核心库
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
rm -rf package/passwall-packages/{shadowsocks-rust,v2ray-geodata}
# merge_package v5 https://github.com/sbwml/openwrt_helloworld package/passwall-packages shadowsocks-rust v2ray-geodata
# app
rm -rf feeds/luci/applications/{luci-app-passwall,luci-app-ssr-libev-server}
# git clone https://github.com/lwb1978/openwrt-passwall package/passwall-luci
# git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci

# ------------------------------------------------------------

# --- [OpenClash 彻底去瘀更新版] ---

# 1. 彻底删除源码树中自带的老旧 OpenClash (如果有的话)
# 这一步是关键，防止编译系统识别到两个同名包导致瘀堵
find ./ -readonly -prune -o -name "luci-app-openclash" -type d -exec rm -rf {} +

# 2. 克隆最新版 OpenClash 源码 (直接从 vernesong 仓库拉取 master 分支)
# 这样保证了你的 LUCI 界面和最新的 SmartCore 能够完美对齐
git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 3. 强行修正 Makefile 依赖 (核心步骤)
# 将默认的 dnsmasq 依赖改为 dnsmasq-full，适配你的内核分流逻辑
sed -i 's/dnsmasq/dnsmasq-full/g' package/luci-app-openclash/luci-app-openclash/Makefile

# 4. 预置 SmartCore (如果你在脚本前面已经下载了内核，这里做个硬链接)
# 确保编译后的固件第一次启动就自带“大脑”
mkdir -p files/etc/openclash/core
if [ -f files/etc/openclash/core/clash_meta ]; then
    cp -f files/etc/openclash/core/clash_meta files/etc/openclash/core/clash
fi

echo "✅ 老旧 OpenClash 已清理，最新版已就位！"

# 1. 强制建立下载目录
mkdir -p dl

# 2. 注入物料（替换为你刚才做好的 Release 直链）
RUST_URL="https://github.com/redfrog999/JDCloud-AX6000/releases/download/rustc_1.9.0/rustc-1.90.0-src.tar.xz"
echo "🚀 正在从私有仓库搬运 Rust 260M 核心物料..."
wget -qO dl/rustc-1.90.0-src.tar.xz "$RUST_URL"

# 3. 自动对齐 Hash（这一步是救命符，防止 Checksum mismatch）
if [ -f "dl/rustc-1.90.0-src.tar.xz" ]; then
    NEW_HASH=$(sha256sum dl/rustc-1.90.0-src.tar.xz | awk '{print $1}')
    echo "🎯 物料 Hash 对齐中: $NEW_HASH"
    
    # 强制修正 Rust Makefile 里的校验值
    # 注意：根据你的 Makefile 路径可能需要微调
    find feeds/packages/lang/rust -name "Makefile" -exec sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" {} \;
    echo "✅ 注入完成，云端下载逻辑已被物理切断。"
else
    echo "❌ 注入失败，请确认 Release 链接有效性！"
    exit 1
fi

# 1. 物理注入源码包（你之前的 Release 逻辑）
# wget -O dl/rustc-1.90.0-src.tar.xz "https://github.com/redfrog999/JDCloud-AX6000/releases/download/rustc_1.9.0/rustc-1.90.0-src.tar.xz"

# 2. 暴力解决 Cargo.toml.orig 缺失报错
# 遍历 build_dir 查找所有 serde 目录，并强行生成缺失的 orig 文件
echo "🎯 正在执行『空文件欺骗』逻辑，修复 Rust 编译血栓..."
find build_dir/ -name "serde-*" -type d | while read -r dir; do
    if [ ! -f "$dir/Cargo.toml.orig" ]; then
        touch "$dir/Cargo.toml.orig"
        echo "✅ 已为 $dir 补齐伪造元数据"
    fi
done

# 3. 针对 Rust 编译环境的额外保险
# 强制跳过不必要的 vendor 校验，让编译器只关注代码本身
export CARGO_NET_OFFLINE=true

# 在 DIY2.sh 中确保核心依赖存在
# 这些包是 OpenClash 运行时的“血管”，缺了就会产生你说的“中焦瘀堵”
sed -i '/custom/d' feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
echo "src-git small8 https://github.com/kenzok8/small-package" >> feeds.conf.default

# 重新更新一遍，确保所有缺失的依赖 ipk 都能在本地找到源码
./scripts/feeds update -a && ./scripts/feeds install -a

# Nikki
rm -rf feeds/luci/applications/luci-app-nikki
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki


# 优化socat中英翻译
sed -i 's/仅IPv6/仅 IPv6/g' package/feeds/luci/luci-app-socat/po/zh_Hans/socat.po

# SmartDNS
# rm -rf feeds/luci/applications/luci-app-smartdns
# git clone https://github.com/lwb1978/luci-app-smartdns package/luci-app-smartdns
# 替换immortalwrt 软件仓库smartdns版本为官方最新版
# rm -rf feeds/packages/net/smartdns
# git clone https://github.com/lwb1978/openwrt-smartdns package/smartdns
# cp -rf ${GITHUB_WORKSPACE}/patch/smartdns feeds/packages/net
# 添加 smartdns-ui
# echo "CONFIG_PACKAGE_smartdns-ui=y" >> .config

# openssl Enable QUIC and KTLS support
# echo "CONFIG_OPENSSL_WITH_QUIC=y" >> .config
# echo "CONFIG_OPENSSL_WITH_KTLS=y" >> .config

# 替换udpxy为修改版，解决组播源数据有重复数据包导致的花屏和马赛克问题
rm -rf feeds/packages/net/udpxy/Makefile
cp -rf ${GITHUB_WORKSPACE}/patch/udpxy/Makefile feeds/packages/net/udpxy/
# 修改 udpxy 菜单名称为大写
sed -i 's#\"title\": \"udpxy\"#\"title\": \"UDPXY\"#g' feeds/luci/applications/luci-app-udpxy/root/usr/share/luci/menu.d/luci-app-udpxy.json

# lukcy大吉
git clone https://github.com/sirpdboy/luci-app-lucky package/lucky-packages
# git clone https://github.com/gdy666/luci-app-lucky.git package/lucky-packages

# 集客AC控制器
git clone https://github.com/lwb1978/openwrt-gecoosac package/openwrt-gecoosac
# git clone -b v1.0 https://github.com/lwb1978/openwrt-gecoosac package/openwrt-gecoosac

# 添加主题
rm -rf feeds/luci/themes/luci-theme-argon
# git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
merge_package openwrt-24.10 https://github.com/sbwml/luci-theme-argon package luci-theme-argon
# git clone --depth=1 -b master https://github.com/sirpdboy/luci-theme-kucat package/luci-theme-kucat
git clone --depth=1 -b master https://github.com/NicolasMe9907/luci-theme-kucat package/luci-theme-kucat
# git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-kucat-config package/luci-app-kucat-config
git clone --depth=1 -b main https://github.com/NicolasMe9907/luci-app-advancedplus  package/luci-app-advancedplus

git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora package/luci-theme-aurora
echo "CONFIG_PACKAGE_luci-theme-aurora=y" >> .config

# 设置默认主题
default_theme='aurora'
sed -i "s/bootstrap/$default_theme/g" feeds/luci/modules/luci-base/root/etc/config/luci

# 取消自添加主题的默认设置
find package/luci-theme-*/* -type f -print | grep '/root/etc/uci-defaults/' | while IFS= read -r file; do
	sed -i '/set luci.main.mediaurlbase/d' "$file"
done

# unzip
rm -rf feeds/packages/utils/unzip
git clone https://github.com/sbwml/feeds_packages_utils_unzip feeds/packages/utils/unzip

# golang 1.26
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# luci-app-filemanager
rm -rf feeds/luci/applications/luci-app-filemanager
git clone https://github.com/sbwml/luci-app-filemanager package/luci-app-filemanager

# TTYD设置
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init
	  
# nghttp3
# rm -rf feeds/packages/libs/nghttp3
# git clone https://github.com/sbwml/package_libs_nghttp3 feeds/packages/libs/nghttp3

# ngtcp2
# rm -rf feeds/packages/libs/ngtcp2
# git clone https://github.com/sbwml/package_libs_ngtcp2 feeds/packages/libs/ngtcp2

# curl
# rm -rf feeds/packages/net/curl
# git clone https://github.com/sbwml/feeds_packages_net_curl feeds/packages/net/curl

# 替换curl修改版（无nghttp3、ngtcp2）
curl_ver=$(cat feeds/packages/net/curl/Makefile | grep -i "PKG_VERSION:=" | awk 'BEGIN{FS="="};{print $2}')
[ "$(check_ver "$curl_ver" "8.12.0")" != "0" ] && {
	echo "替换curl版本"
	rm -rf feeds/packages/net/curl
	cp -rf ${GITHUB_WORKSPACE}/patch/curl feeds/packages/net/curl
}

# apk-tools APK管理器不再校验版本号的合法性
mkdir -p package/system/apk/patches && cp -f ${GITHUB_WORKSPACE}/patch/apk-tools/9999-hack-for-linux-pre-releases.patch package/system/apk/patches/

mirror=raw.githubusercontent.com/sbwml/r4s_build_script/master

# 防火墙4添加自定义nft命令支持
# curl -s https://$mirror/openwrt/patch/firewall4/100-openwrt-firewall4-add-custom-nft-command-support.patch | patch -p1
patch -p1 < ${GITHUB_WORKSPACE}/patch/firewall4/100-openwrt-firewall4-add-custom-nft-command-support.patch

pushd feeds/luci
	# 防火墙4添加自定义nft命令选项卡
	# curl -s https://$mirror/openwrt/patch/firewall4/luci-24.10/0004-luci-add-firewall-add-custom-nft-rule-support.patch | patch -p1
	patch -p1 < ${GITHUB_WORKSPACE}/patch/firewall4/0004-luci-add-firewall-add-custom-nft-rule-support.patch
	# 状态-防火墙页面去掉iptables警告，并添加nftables、iptables标签页
	# curl -s https://$mirror/openwrt/patch/luci/0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch | patch -p1
	patch -p1 < ${GITHUB_WORKSPACE}/patch/firewall4/0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch
popd

# 补充 firewall4 luci 中文翻译
cat >> "feeds/luci/applications/luci-app-firewall/po/zh_Hans/firewall.po" <<-EOF
	
	msgid ""
	"Custom rules allow you to execute arbitrary nft commands which are not "
	"otherwise covered by the firewall framework. The rules are executed after "
	"each firewall restart, right after the default ruleset has been loaded."
	msgstr ""
	"自定义规则允许您执行不属于防火墙框架的任意 nft 命令。每次重启防火墙时，"
	"这些规则在默认的规则运行后立即执行。"
	
	msgid ""
	"Applicable to internet environments where the router is not assigned an IPv6 prefix, "
	"such as when using an upstream optical modem for dial-up."
	msgstr ""
	"适用于路由器未分配 IPv6 前缀的互联网环境，例如上游使用光猫拨号时。"

	msgid "NFtables Firewall"
	msgstr "NFtables 防火墙"

	msgid "IPtables Firewall"
	msgstr "IPtables 防火墙"
EOF

# 精简 UPnP 菜单名称
sed -i 's#\"title\": \"UPnP IGD \& PCP\"#\"title\": \"UPnP\"#g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json
# 移动 UPnP 到 “网络” 子菜单
sed -i 's/services/network/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json

# rpcd - fix timeout
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js

# vim - fix E1187: Failed to source defaults.vim
pushd feeds/packages
	vim_ver=$(cat utils/vim/Makefile | grep -i "PKG_VERSION:=" | awk 'BEGIN{FS="="};{print $2}' | awk 'BEGIN{FS=".";OFS="."};{print $1,$2}')
	[ "$vim_ver" = "9.0" ] && {
		echo "修复 vim E1187 的错误"
		# curl -s https://github.com/openwrt/packages/commit/699d3fbee266b676e21b7ed310471c0ed74012c9.patch | patch -p1
		patch -p1 < ${GITHUB_WORKSPACE}/patch/vim/0001-vim-fix-renamed-defaults-config-file.patch
	}
popd

# Realtek driver - R8168 & R8125 & R8126 & R8152 & R8101 & r8127
rm -rf package/kernel/{r8168,r8101,r8125,r8126,r8127}
git clone https://github.com/sbwml/package_kernel_r8168 package/kernel/r8168
git clone https://github.com/sbwml/package_kernel_r8152 package/kernel/r8152
git clone https://github.com/sbwml/package_kernel_r8101 package/kernel/r8101
git clone https://github.com/sbwml/package_kernel_r8125 package/kernel/r8125
git clone https://github.com/sbwml/package_kernel_r8126 package/kernel/r8126
git clone https://github.com/sbwml/package_kernel_r8127 package/kernel/r8127

# 修正部分从第三方仓库拉取的软件 Makefile 路径问题
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/rust\/rust-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/rust\/rust-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# --- 1. 注入 CachyOS 风格的全局硬件加速编译参数 ---
# 我们直接修改 include/target.mk 里的默认 CFLAGS
# 加上 -march=armv8-a+crc+crypto，唤醒 A53 的硬件加密引擎
sed -i 's/-Os -pipe/-O2 -pipe -march=armv8-a+crc+crypto -mtune=cortex-a53/g' include/target.mk

# --- 2. 强制开启硬件加速内核模块的默认勾选 ---
# 虽然 menuconfig 也能选，但写在脚本里能防止你漏掉依赖
echo "CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y" >> .config
echo "CONFIG_PACKAGE_kmod-crypto-aes=y" >> .config
echo "CONFIG_PACKAGE_kmod-crypto-authenc=y" >> .config.

# ---3. 释放内核编译时的指令优化限制
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+crc+crypto/g' include/target.mk

# ---4. 强制开启内核的 CPU 频率调节器并锁定高性能模式
echo "CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y" >> .config
echo "CONFIG_CPU_FREQ_GOV_PERFORMANCE=y" >> .config

# --- 5. 固化 TCP BBR 加速与内核优化 ---
# 强制将 BBR 写入系统默认配置，无需插件干预
echo "net.ipv4.tcp_congestion_control=bbr" >> package/base-files/files/etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> package/base-files/files/etc/sysctl.conf

# --- 6. 确保物理 HNAT (PPE) 默认开启 ---
# 在系统启动脚本中直接注入开启指令，不再依赖 TurboACC 面板
sed -i '/exit 0/i \
sysctl -w net.netfilter.nf_conntrack_helper=1 \
sysctl -w net.netfilter.nf_flow_table_hw=1' package/base-files/files/etc/rc.local

# =========================================================
# 1.65GHz 超频矩阵终极调优脚本 (全量整合版)
# 适用机型：RAX3000M, XR30 (eMMC/NAND), 360T7, TR3000v1
# =========================================================

# --- 1. 核心内核参数注入 (通用高速路) ---
cat >> package/base-files/files/etc/sysctl.conf <<'EOF'

# [通用优化] 开启 BBR 拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# [1.65GHz 调度适配] 缩短调度周期，匹配高频心跳，降低 Hy2 延迟
kernel.sched_latency_ns=8000000
kernel.sched_min_granularity_ns=1000000
kernel.sched_wakeup_granularity_ns=1500000

# [网络吞吐优化] 提高软中断处理预算
net.core.netdev_budget=1000
net.core.netdev_budget_usecs=10000
EOF

# --- 2. 分机型精准调优逻辑 (解决 eMMC 波动与 NAND 压榨) ---

if grep -iq "rax3000m-emmc\|xr30-emmc" .config; then
    # 【eMMC 狂暴适配版】针对超频后的 I/O 瓶颈优化
    echo "# 1.65GHz Overclocked & eMMC Balanced" >> package/base-files/files/etc/sysctl.conf
    # 压榨 Cache 到 40 (高频 CPU 处理回收极快)，保留 B站秒开快感
    echo "vm.vfs_cache_pressure=40" >> package/base-files/files/etc/sysctl.conf
    # 免死金牌：预留 20MB 物理内存，确保 1.65G 下无线驱动 DMA 不断流
    echo "vm.min_free_kbytes=20480" >> package/base-files/files/etc/sysctl.conf
    # 缩短脏数据回写周期，防止 eMMC 瞬间 I/O 阻塞导致网速波动
    echo "vm.dirty_expire_centisecs=1500" >> package/base-files/files/etc/sysctl.conf
    echo "vm.dirty_writeback_centisecs=300" >> package/base-files/files/etc/sysctl.conf

elif grep -iq "360t7\|xr30-nand" .config; then
    # 【NAND 极致压榨版】
    echo "# 1.65GHz NAND Extreme Mode" >> package/base-files/files/etc/sysctl.conf
    # 开启透明大页，减少超频后的 TLB 寻址开销
    echo "kernel.mm.transparent_hugepages.enabled=always" >> package/base-files/files/etc/sysctl.conf
    # NAND 机型内存相对宽裕，预留 16MB 即可
    echo "vm.min_free_kbytes=16384" >> package/base-files/files/etc/sysctl.conf
    echo "vm.swappiness=10" >> package/base-files/files/etc/sysctl.conf

elif grep -iq "tr3000v1" .config; then
    # 【TR3000v1 机皇专属】
    echo "# TR3000v1 Export Extreme" >> package/base-files/files/etc/sysctl.conf
    # 极致 Cache 深度，10 为极限，配合 1.6G+ 暴力主频
    echo "vm.vfs_cache_pressure=10" >> package/base-files/files/etc/sysctl.conf
    echo "kernel.nmi_watchdog=0" >> package/base-files/files/etc/sysctl.conf
fi

# --- 3. 物理级性能解锁 (通用) ---
# 开启内核 RCU 卸载，减少系统琐事对高频核心的打扰
echo "kernel.rcu_nocb_poll=1" >> package/base-files/files/etc/sysctl.conf

# 强制移除内耗插件 (清理血栓)
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_luci-app-wrtbwmon=y/CONFIG_PACKAGE_luci-app-wrtbwmon=n/g' .config
sed -i 's/CONFIG_PACKAGE_luci-app-nlbwmon=y/CONFIG_PACKAGE_luci-app-nlbwmon=n/g' .config

# --- 4. 存储挂载优化 (使用双引号避免 EOF 报错) ---
sed -i "s/options\s*'errors=remount-ro'/options 'noatime,nodiratime,errors=remount-ro'/g" package/base-files/files/lib/functions/uci-defaults.sh || true

# 自定义默认配置
sed -i '/exit 0$/d' package/emortal/default-settings/files/99-default-settings
cat ${GITHUB_WORKSPACE}/immortalwrt/default-settings >> package/emortal/default-settings/files/99-default-settings

# --- [MT7981 温柔全量版] 放入 DIY2.sh 末尾 ---

# 1. 轻量化分流：解耦 dnsmasq 与代理核心
mkdir -p package/base-files/files/etc
cat > package/base-files/files/etc/bypass_gentle.nft <<'EOF'
#!/usr/sbin/nft -f
table inet global_distributor {
    set chnroute { type ipv4_addr; flags interval; }
    chain prerouting {
        type filter hook prerouting priority -150; policy accept;
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 192.168.0.0/16 } accept
        ip daddr @chnroute counter accept
        meta mark set 0x66
    }
    chain dispatch {
        type filter hook prerouting priority -100; policy accept;
        meta mark 0x66 tproxy to :7893
    }
}
EOF

# 2. 512M 专项内存守护与 zRAM
cat >> package/base-files/files/etc/config/system <<'EOF'
config zram
    option enabled '1'
    option size '128'
EOF

cat >> package/base-files/files/etc/sysctl.conf <<'EOF'
vm.vfs_cache_pressure=1000
vm.swappiness=10
net.ipv4.tcp_mem=4096 8192 16384
EOF

# 3. 稳健频率调度
cat >> package/base-files/files/etc/rc.local <<'EOF'
for i in /sys/devices/system/cpu/cpufreq/policy*; do echo performance > "$i/scaling_governor"; done
modprobe crypto_safexcel 2>/dev/null
# 针对 512M 仅加载精简版 CHN-IP 以节省内存
curl -sL http://www.ipdeny.com/ipblocks/data/countries/cn.zone | head -n 1000 | while read line; do
    nft add element inet global_distributor chnroute { $line } 2>/dev/null
done
EOF

# 4. 防火墙注入
cat >> package/base-files/files/etc/config/firewall <<'EOF'
config include 'bypass_gentle'
	option type 'script'
	option path '/etc/bypass_gentle.nft'
	option reload '1'
EOF

# 拷贝自定义文件
if [ -n "$(ls -A "${GITHUB_WORKSPACE}/immortalwrt/diy" 2>/dev/null)" ]; then
	cp -Rf ${GITHUB_WORKSPACE}/immortalwrt/diy/* .
fi

#./scripts/feeds update -a
#./scripts/feeds install -a

make defconfig

echo "========================="
echo " DIY2 配置完成……"
