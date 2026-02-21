#!/bin/bash

echo "开始执行【万里版】逻辑对齐重构脚本……"
echo "========================="

# --- 0. 基础环境清理与物理去瘀 ---
# 修改默认IP
sed -i 's/192.168.6.1/192.168.33.1/g' package/base-files/files/bin/config_generate

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

#!/bin/bash

# =========================================================
# 1. 指令集重构：底层基因“合闸”
# =========================================================
# 针对 Cortex-A53 核心，开启 LSE 原子指令、CRC、Crypto 扩展
sed -i 's/TARGET_CFLAGS += -fno-align-functions/TARGET_CFLAGS += -march=armv8-a+lse+crc+crypto -mtune=cortex-a53 -O3/g' include/target.mk

# =========================================================
# 2. 内核秘籍注入：6.6.95 满血特性
# =========================================================
KERNEL_CONF="target/linux/mediatek/filogic/config-6.6"

cat >> $KERNEL_CONF <<EOF
# [原子级同步]
CONFIG_ARM64_LSE_ATOMICS=y
CONFIG_ARM64_USE_LSE_ATOMICS=y

# [内核态 TLS 卸载]
CONFIG_TLS=y
CONFIG_TLS_DEVICE=y

# [高性能网络基座]
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_HAVE_EBPF_JIT=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_NET_XGRESS=y
CONFIG_NET_CLS_BPF=y

# [硬件加速引擎]
CONFIG_CRYPTO_DEV_SAFEXCEL=y
CONFIG_NET_MEDIATEK_SOC_WED=y
CONFIG_NET_MEDIATEK_SOC_PPE=y

# [内存折叠压缩]
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
EOF

# =========================================================
# 3. 运行态矩阵：创建流水线隔离脚本 (统一入口)
# =========================================================
mkdir -p package/base-files/files/etc/init.d

cat > package/base-files/files/etc/init.d/matrix_logic <<EOF
#!/bin/sh /etc/rc.common
START=99

boot() {
    # 检测核心数量，自动对齐逻辑断点 (MT7981为2核, MT7986为4核)
    CPU_COUNT=\$(grep -c ^processor /proc/cpuinfo)

    # 唤醒硬件加速基因
    modprobe crypto_safexcel 2>/dev/null
    echo 1 > /proc/sys/net/netfilter/nf_flow_table_hw 2>/dev/null
    modprobe tls 2>/dev/null
    echo 1 > /sys/module/tls/parameters/tls_hw 2>/dev/null

    # 获取中断号
    ETH_IRQ=\$(grep -m1 "mtk-network" /proc/interrupts | cut -d: -f1 | tr -d ' ')
    WIFI_IRQ=\$(grep -E "mt7981|mt7986" /proc/interrupts | head -n1 | cut -d: -f1 | tr -d ' ')
    CRYPTO_IRQ=\$(grep -E "safexcel|eip" /proc/interrupts | awk -F: '{print \$1}' | tr -d ' ')

    if [ "\$CPU_COUNT" -eq 4 ]; then
        # [MT7986 四核矩阵模式]
        # CPU0,1 搬运 (Mask 3) | CPU2,3 计算 (Mask C)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 3 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo c > "/proc/irq/\$irq/smp_affinity"; done
        # RPS 泵向计算簇 (CPU2,3 -> Mask C)
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo c > "\$x"; done
    else
        # [MT7981 双核异步模式]
        # CPU0 搬运 (Mask 1) | CPU1 计算 (Mask 2)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 1 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo 2 > "/proc/irq/\$irq/smp_affinity"; done
        # RPS 泵向计算核心 (CPU1 -> Mask 2)
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo 2 > "\$x"; done
    fi

    # 全量开启溢出缓冲与 TCP 巅峰参数
    echo 16384 > /proc/sys/net/core/rps_sock_flow_entries
    for rps_flow in /sys/class/net/*/queues/rx-*/rps_flow_cnt; do echo 2048 > "\$rps_flow"; done

    # 锁定巅峰频率 (配合大铜片散热)
    for i in \$(seq 0 \$((\$CPU_COUNT - 1))); do
        echo "performance" > /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_governor
    done

    # 六招归一：最终协议栈合闸
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sysctl -w net.ipv4.tcp_fastopen=3
    sysctl -w net.ipv4.tcp_low_latency=1
}
EOF

chmod +x package/base-files/files/etc/init.d/matrix_logic

# =========================================================
# 4. 资产精简与版本注入
# =========================================================
sed -i 's/CONFIG_DEBUG_INFO=y/CONFIG_DEBUG_INFO=n/g' $KERNEL_CONF
echo "CONFIG_DYNAMIC_DEBUG=n" >> $KERNEL_CONF
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWrt-Matrix-Turbo-v1.0-6.6.95'/g" package/base-files/files/etc/openwrt_release

# 1. 喚醒硬件引擎編譯參數 (全量開啟 SafeXcel 優化)
# 直接修改全局 Target 配置，讓編譯器輸出針對 Cortex-A53 深度優化的二進制文件
sed -i 's/-Os -pipe/-O2 -pipe -march=armv8-a+crc+crypto -mtune=cortex-a53/g' include/target.mk
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+crc+crypto/g' include/target.mk

# 2. 定向注入硬解模塊與性能模式
# 根據你的 .config 邏輯，直接追加入編譯配置中
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_kmod-crypto-aes=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
# 四合一模式必選：確保硬件中繼加速模塊入庫
CONFIG_PACKAGE_kmod-mtk-eth-hw-offload=y
EOF

# 3. 如果是針對 MT7986 (四核)，可以進一步釋放算力權限
if grep -q "CONFIG_TARGET_mediatek_filogic_DEVICE_mediatek_mt7986" .config; then
    echo "CONFIG_NR_CPUS=4" >> .config
    # 這裡可以加入更多針對四核 A53 的專屬內核參數
fi

# --- 4. 系统内核优化 (全量对齐) ---

# 定义文件路径变量
SYSCTL_PATH="package/base-files/files/etc/sysctl.conf"

# 1. 物理級性能解鎖 (通用)
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_wrtbwmon=y/CONFIG_PACKAGE_wrtbwmon=n/g' .config

# 2.物理 HNAT (PPE) 开启逻辑注入
sed -i '/exit 0/i \
sysctl -w net.netfilter.nf_flow_table_hw=1 \
for i in /sys/devices/system/cpu/cpufreq/policy*; do echo performance > "$i/scaling_governor"; done \
modprobe crypto_safexcel 2>/dev/null' package/base-files/files/etc/rc.local

# --- 5. 分机型适配与配置固化 ---

# a. 分機型精準注入 (寫入固件靜態配置)
if grep -iq "rax3000m-emmc\|xr30-emmc" .config; then
    # eMMC 狂暴適配：縮短回寫週期，防止 I/O 阻塞導致網速波動
    cat >> $SYSCTL_PATH <<EOF
vm.vfs_cache_pressure=40
vm.dirty_expire_centisecs=1500
vm.dirty_writeback_centisecs=300
EOF
elif grep -iq "360t7\|xr30-nand" .config; then
    # NAND 模式：開啟透明大頁
    echo "kernel.mm.transparent_hugepages.enabled=always" >> $SYSCTL_PATH
    echo "vm.swappiness=10" >> $SYSCTL_PATH
elif grep -iq "tr3000v1" .config; then
    # TR3000v1：機皇專屬極致 Cache
    echo "vm.vfs_cache_pressure=10" >> $SYSCTL_PATH
fi

# b. 注入 RCU 核心卸載 (通用內核調優)
echo "kernel.rcu_nocb_poll=1" >> $SYSCTL_PATH

# 最后的逻辑收束
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

echo "========================="
echo "✅ DIY2 逻辑重组完成，等待咆哮！"
