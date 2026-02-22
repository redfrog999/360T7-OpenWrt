#!/bin/bash

echo "开始执行【万里版】逻辑对齐重构脚本……"
echo "========================="

# --- 0. 基础环境清理与物理去瘀 ---
# 修改默认IP
sed -i 's/192.168.6.1/192.168.25.1/g' package/base-files/files/bin/config_generate

# 彻底清理 PassWall、老旧 OpenClash 和残留核心库 (防止逻辑冲突)
rm -rf feeds/packages/net/{xray*,v2ray*,sing-box,hysteria*,shadowsocks*,trojan*,clash*}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/passwall-packages

# --- 1. 添加主题及筑底建基
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

# 启用Golang 1.26
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

# --- 2. 插件与核心物料注入 (逻辑对齐) ---

# 克隆 Nikki (基于 Mihomo)
rm -rf feeds/luci/applications/luci-app-nikki
git clone https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki

# 克隆最新版 OpenClash 并强制对齐 dnsmasq-full
find ./ -name "luci-app-openclash" -type d -exec rm -rf {} +
git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

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

#!/bin/bash

# =========================================================
# 1. 物理层定调：锁定 2.2GHz (四核全开，同步巅峰)
# =========================================================
find target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/ -name "*.dts*" | xargs sed -i 's/2000000/2200000/g' 2>/dev/null

# =========================================================
# 2. 内核特性：合闸卸载引擎 (PPE + WED + ZSTD)
# =========================================================
KERNEL_CONF="target/linux/mediatek/filogic/config-6.6"
cat >> $KERNEL_CONF <<EOF
CONFIG_NET_MEDIATEK_SOC_WED=y
CONFIG_NET_MEDIATEK_SOC_PPE=y
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_RCU_NOCB_CPU=y
CONFIG_RCU_NOCB_CPU_ALL=y
EOF

# =========================================================
# 3. 注入 smp_optimize：四核有序分工逻辑
# =========================================================
mkdir -p package/base-files/files/etc/init.d
cat > package/base-files/files/etc/init.d/smp_optimize <<EOF
#!/bin/sh /etc/rc.common
START=99

boot() {
    # 锁定四核性能模式
    for i in 0 1 2 3; do echo "performance" > /sys/devices/system/cpu/cpu\\\$i/cpufreq/scaling_governor; done

    # 精准识别 IRQ (使用地址匹配法避免脑雾)
    ETH_IRQ=\\\$(grep "15100000.ethernet" /proc/interrupts | awk -F: '{print \\\$1}' | tr -d ' ' | head -n1)
    CRYPTO_IRQ=\\\$(grep "10320000.crypto" /proc/interrupts | awk -F: '{print \\\$1}' | tr -d ' ')

    # [策略：有序分配]
    # 1. 硬中断分配：由 Core 1, 2, 3 共同承载 (Mask E = 1110)
    # 留出 Core 0 专门维护系统稳态和高优先级的管理任务
    [ -n "\\\$ETH_IRQ" ] && echo "e" > "/proc/irq/\\\$ETH_IRQ/smp_affinity"
    for irq in \\\$CRYPTO_IRQ; do echo "e" > "/proc/irq/\\\$irq/smp_affinity"; done

    # 2. RPS/XPS 协议栈卸载：四核全参与 (Mask F = 1111)
    # 让每一个 A53 核心都有机会处理协议栈解压和解密，实现真正的“打群架”
    for x in /sys/class/net/eth*/queues/rx-*/rps_cpus; do echo "f" > "\\\$x"; done
    for x in /sys/class/net/eth*/queues/tx-*/xps_cpus; do echo "f" > "\\\$x"; done
    
    # 3. 极大化 RFS 套接字哈希表
    echo "32768" > /proc/sys/net/core/rps_sock_flow_entries
    for x in /sys/class/net/eth*/queues/rx-*/rps_flow_cnt; do echo "8192" > "\\\$x"; done

    # 4. 暴力开启 PPE 硬件加速 (减免 CPU 转发税)
    echo 1 > /sys/kernel/debug/hnat/all_external 2>/dev/null
    echo 1 > /sys/kernel/debug/hnat/all_internal 2>/dev/null
}
EOF

chmod +x package/base-files/files/etc/init.d/smp_optimize

# =========================================================
# 4. 资产收束与双保险 (MT7986 终极加固版)
# =========================================================

# 确保目录必须存在
mkdir -p package/base-files/files/etc/init.d
mkdir -p package/base-files/files/etc/uci-defaults

# 1. 赋予 smp_optimize 脚本执行权限 (这是前提)
chmod +x package/base-files/files/etc/init.d/smp_optimize

# 2. 写入双保险自启动逻辑
cat > package/base-files/files/etc/uci-defaults/99-smp-config <<EOF
#!/bin/sh
# 这一步会自动补全 /etc/rc.d/S99smp_optimize 链接
/etc/init.d/smp_optimize enable
# 这一步立刻执行调频、PPE 开启和四核均衡策略
/etc/init.d/smp_optimize start
exit 0
EOF

# 3. 更新版本描述
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWrt-MT7986-2.2G-Balance-v4.0'/g" package/base-files/files/etc/openwrt_release

# 4. 最后进行 feeds 更新和配置生成
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

# a. 强制开启内核的 CPU 频率调节器并锁定高性能模式
echo "CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y" >> .config
echo "CONFIG_CPU_FREQ_GOV_PERFORMANCE=y" >> .config

# b.统一注入 sysctl 参数 (BBR + 调度优化)
cat >> package/base-files/files/etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
vm.vfs_cache_pressure=40
vm.min_free_kbytes=20480
EOF

# c.[ 内核调度调优：针对 A53 1.6&2.3GHz 优化 缩短调度周期，匹配高频心跳，降低 Hy2 延迟|[网络吞吐优化] 提高软中断处理预算 ]
# 使用 append 模式写入 sysctl.conf
cat << 'EOF' >> package/base-files/files/etc/sysctl.conf
kernel.sched_latency_ns=8000000
kernel.sched_min_granularity_ns=1000000
kernel.sched_wakeup_granularity_ns=1500000
net.core.netdev_budget=1000
net.core.netdev_budget_usecs=10000
EOF

# d.物理 HNAT (PPE) 开启逻辑注入
sed -i '/exit 0/i \
sysctl -w net.netfilter.nf_flow_table_hw=1 \
for i in /sys/devices/system/cpu/cpufreq/policy*; do echo performance > "$i/scaling_governor"; done \
modprobe crypto_safexcel 2>/dev/null' package/base-files/files/etc/rc.local

# B. 物理级性能解锁 (通用) ---
# 开启内核 RCU 卸载，减少系统琐事对高频核心的打扰
echo "kernel.rcu_nocb_poll=1" >> package/base-files/files/etc/sysctl.conf

# C.根据 .config 自动检测并删除冗余监控插件 (清理内耗)
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_wrtbwmon=y/CONFIG_PACKAGE_wrtbwmon=n/g' .config

# D.拷贝自定义 DIY 目录 (如果存在)
[ -d "${GITHUB_WORKSPACE}/immortalwrt/diy" ] && cp -Rf ${GITHUB_WORKSPACE}/immortalwrt/diy/* .

# 最后的逻辑收束

# 确保硬件加速模块入库
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_kmod-crypto-aes=y
CONFIG_PACKAGE_kmod-mtk-eth-hw-offload=y
EOF

./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

echo "========================="
echo "✅ DIY2 逻辑重组完成，等待咆哮！"
