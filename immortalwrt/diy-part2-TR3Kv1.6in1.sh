#!/bin/bash

echo "开始执行【万里版】逻辑对齐重构脚本……"
echo "========================="

# --- 0. 基础环境清理与物理去瘀 ---
# 修改默认IP
sed -i 's/192.168.6.1/192.168.15.1/g' package/base-files/files/bin/config_generate

# 彻底清理 PassWall、老旧 OpenClash 和残留核心库 (防止逻辑冲突)
rm -rf feeds/packages/net/{xray*,v2ray*,sing-box,hysteria*,shadowsocks*,trojan*,clash*}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/passwall-packages

# --- 1. 添加主题及筑底构建
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

# 启用Golang 1.26编译
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# TTYD设置
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init

# vim - fix E1187: Failed to source defaults.vim
pushd feeds/packages
	vim_ver=$(cat utils/vim/Makefile | grep -i "PKG_VERSION:=" | awk 'BEGIN{FS="="};{print $2}' | awk 'BEGIN{FS=".";OFS="."};{print $1,$2}')
	[ "$vim_ver" = "9.0" ] && {
		echo "修复 vim E1187 的错误"
		# curl -s https://github.com/openwrt/packages/commit/699d3fbee266b676e21b7ed310471c0ed74012c9.patch | patch -p1
		patch -p1 < ${GITHUB_WORKSPACE}/patch/vim/0001-vim-fix-renamed-defaults-config-file.patch
	}
popd

# --- 2. 插件与核心物料注入 (逻辑对齐) ---

# 克隆 Nikki (基于 Mihomo)
rm -rf feeds/luci/applications/luci-app-nikki
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# 克隆最新版 OpenClash 并强制对齐 dnsmasq-full
find ./ -name "luci-app-openclash" -type d -exec rm -rf {} +
git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# --- 3. 硬件性能加速与指令集对齐 (SafeXcel & A53) ---

# MT7981专属修改设备树，将默认频率改为 1.6G (1600MHz)
find target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/ -name "*.dts*" | xargs sed -i 's/1300000/1600000/g' 2>/dev/null


# =========================================================
# 1. 指令集重构：回归物理硬解 (去 LSE，留 Crypto+CRC)
# =========================================================
# 剔除 -Os 带来的性能断流，开启针对 A53 的 O2 深度优化
sed -i 's/-Os -pipe/-O2 -pipe -march=armv8-a+crc+crypto -mtune=cortex-a53/g' include/target.mk
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+crc+crypto/g' include/target.mk

# =========================================================
# 2. 内核特性：kTLS 硬件卸载与 BPF 满血版
# =========================================================
KERNEL_CONF="target/linux/mediatek/filogic/config-6.6"

cat >> $KERNEL_CONF <<EOF
# [kTLS 核心合闸：翻墙性能倍增器]
CONFIG_TLS=y
CONFIG_TLS_DEVICE=y
CONFIG_TLS_TOE=y

# [硬件加速矩阵：MTK 物理引擎全开]
CONFIG_CRYPTO_DEV_SAFEXCEL=y
CONFIG_NET_MEDIATEK_SOC_WED=y
CONFIG_NET_MEDIATEK_SOC_PPE=y

# [高性能网络基座：Hy2 专用低延迟 BPF]
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_HAVE_EBPF_JIT=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_NET_XGRESS=y
CONFIG_NET_CLS_BPF=y

# [内存策略：ZSTD 压缩提升 4-in-1 容错率]
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
EOF

# =========================================================
# 3. 系统调度调优：匹配 1.6GHz 巅峰频率
# =========================================================
SYSCTL_PATH="package/base-files/files/etc/sysctl.conf"

cat >> $SYSCTL_PATH <<EOF
# [内核调度：缩短周期，降低 Hy2 延迟]
kernel.sched_latency_ns=8000000
kernel.sched_min_granularity_ns=1000000
kernel.sched_wakeup_granularity_ns=1500000

# [吞吐优化：提高软中断处理预算，应对 2.5G 暴量]
net.core.netdev_budget=1000
net.core.netdev_budget_usecs=10000

# [BBRv3 + FQ 巅峰配置]
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1

# [通用调度：减少琐事对高频核心的打扰]
kernel.rcu_nocb_poll=1
EOF

# =========================================================
# 4. 分机型精准调优：解决 eMMC 波动与 NAND 压榨 (已补回)
# =========================================================
if grep -iq "rax3000m-emmc\|xr30-emmc" .config; then
    # 【eMMC 狂暴适配版】
    cat >> $SYSCTL_PATH <<EOF
# 1.65GHz Overclocked & eMMC Balanced
vm.vfs_cache_pressure=40
vm.min_free_kbytes=20480
vm.dirty_expire_centisecs=1500
vm.dirty_writeback_centisecs=300
EOF
elif grep -iq "360t7\|xr30-nand" .config; then
    # 【NAND 极致压榨版】
    cat >> $SYSCTL_PATH <<EOF
# 1.65GHz NAND Extreme Mode
kernel.mm.transparent_hugepages.enabled=always
vm.min_free_kbytes=16384
vm.swappiness=10
EOF
elif grep -iq "tr3000v1" .config; then
    # 【TR3000v1 机皇专属】
    cat >> $SYSCTL_PATH <<EOF
# TR3000v1 Export Extreme
vm.vfs_cache_pressure=10
kernel.nmi_watchdog=0
EOF
fi

# =========================================================
# 5. 运行态矩阵：IRQ 隔离与 kTLS 硬件激活
# =========================================================
mkdir -p package/base-files/files/etc/init.d

cat > package/base-files/files/etc/init.d/matrix_logic <<EOF
#!/bin/sh /etc/rc.common
START=99

boot() {
    CPU_COUNT=\$(grep -c ^processor /proc/cpuinfo)

    # 激活 kTLS 与 SafeXcel 硬件逻辑
    modprobe tls 2>/dev/null
    echo 1 > /sys/module/tls/parameters/tls_hw 2>/dev/null
    modprobe crypto_safexcel 2>/dev/null
    echo 1 > /proc/sys/net/netfilter/nf_flow_table_hw 2>/dev/null

    # 精准 IRQ 分配
    ETH_IRQ=\$(grep -m1 "mtk-network" /proc/interrupts | cut -d: -f1 | tr -d ' ')
    CRYPTO_IRQ=\$(grep -E "safexcel|eip" /proc/interrupts | awk -F: '{print \$1}' | tr -d ' ')

    if [ "\$CPU_COUNT" -eq 4 ]; then
        for irq in \$ETH_IRQ; do echo 3 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo c > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo c > "\$x"; done
    else
        for irq in \$ETH_IRQ; do echo 1 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo 2 > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo 2 > "\$x"; done
    fi

    # 锁定性能模式
    for i in \$(seq 0 \$((\$CPU_COUNT - 1))); do
        echo "performance" > /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_governor
    done
}
EOF

chmod +x package/base-files/files/etc/init.d/matrix_logic

# =========================================================
# 6. 编译资产收束
# =========================================================
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWrt-Matrix-4in1-v3.5-Turbo'/g" package/base-files/files/etc/openwrt_release
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

echo "✅ DIY2 全量逻辑合闸完成，等待起飞！"
