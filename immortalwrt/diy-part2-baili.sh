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

#!/bin/bash

# =========================================================
# 1. 环境预热：拉取最新 Feeds 并强制对齐
# =========================================================
./scripts/feeds update -a && ./scripts/feeds install -a

# =========================================================
# 2. 基因重构：Cortex-A53 暴力指令集优化 (全量对齐)
# =========================================================
# 统一所有地方的编译参数，确保 LSE 原子指令、CRC、Crypto 贯穿始终
sed -i 's/-Os -pipe/-O3 -pipe -march=armv8-a+lse+crc+crypto -mtune=cortex-a53/g' include/target.mk
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+lse+crc+crypto/g' include/target.mk
sed -i 's/TARGET_CFLAGS += -fno-align-functions/TARGET_CFLAGS += -march=armv8-a+lse+crc+crypto -mtune=cortex-a53/g' include/target.mk

# =========================================================
# 3. 内核秘籍注入：6.6.95 强力合闸 (解决 syncconfig 报错)
# =========================================================
KERNEL_CONF="target/linux/mediatek/filogic/config-6.6"

# 强制替换/追加内核宏，确保依赖项全部激活
update_kernel_config() {
    sed -i "/$1/d" $KERNEL_CONF
    echo "$1=$2" >> $KERNEL_CONF
}

# [原子级同步] 极致利用 1.65GHz
update_kernel_config "CONFIG_ARM64_LSE_ATOMICS" "y"
update_kernel_config "CONFIG_ARM64_USE_LSE_ATOMICS" "y"
# [kTLS 加速]
update_kernel_config "CONFIG_TLS" "y"
update_kernel_config "CONFIG_TLS_DEVICE" "y"
# [硬件引擎驱动]
update_kernel_config "CONFIG_CRYPTO_DEV_SAFEXCEL" "y"
update_kernel_config "CONFIG_NET_MEDIATEK_SOC_WED" "y"
update_kernel_config "CONFIG_NET_MEDIATEK_SOC_PPE" "y"
# [内存折叠与 BPF 加速]
update_kernel_config "CONFIG_ZRAM" "y"
update_kernel_config "CONFIG_ZRAM_DEF_COMP_ZSTD" "y"
update_kernel_config "CONFIG_DEBUG_INFO_BTF" "y"
update_kernel_config "CONFIG_DEBUG_INFO" "n"
update_kernel_config "CONFIG_DYNAMIC_DEBUG" "n"

# =========================================================
# 4. 运行态矩阵：创建流水线隔离脚本 (入库系统启动项)
# =========================================================
mkdir -p package/base-files/files/etc/init.d

cat > package/base-files/files/etc/init.d/matrix_logic <<EOF
#!/bin/sh /etc/rc.common
START=99

boot() {
    # 检测核心数量，自动对齐逻辑断点
    CPU_COUNT=\$(grep -c ^processor /proc/cpuinfo)

    # 唤醒硬件引擎与 kTLS 硬件合闸
    modprobe crypto_safexcel 2>/dev/null
    modprobe tls 2>/dev/null
    echo 1 > /sys/module/tls/parameters/tls_hw 2>/dev/null
    echo 1 > /proc/sys/net/netfilter/nf_flow_table_hw 2>/dev/null

    # 中断号动态获取
    ETH_IRQ=\$(grep -m1 "mtk-network" /proc/interrupts | cut -d: -f1 | tr -d ' ')
    WIFI_IRQ=\$(grep -E "mt7981|mt7986" /proc/interrupts | head -n1 | cut -d: -f1 | tr -d ' ')
    CRYPTO_IRQ=\$(grep -E "safexcel|eip" /proc/interrupts | awk -F: '{print \$1}' | tr -d ' ')

    if [ "\$CPU_COUNT" -eq 4 ]; then
        # [MT7986 四核模式] CPU0,1 搬运 | CPU2,3 计算 (Mask C)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 3 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo c > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo c > "\$x"; done
    else
        # [MT7981 双核模式] CPU0 搬运 | CPU1 计算 (Mask 2)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 1 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo 2 > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo 2 > "\$x"; done
    fi

    # 流量接力缓冲区优化
    echo 16384 > /proc/sys/net/core/rps_sock_flow_entries
    for rps_flow in /sys/class/net/*/queues/rx-*/rps_flow_cnt; do echo 2048 > "\$rps_flow"; done

    # 锁定巅峰频率 (配合大铜片散热)
    for i in \$(seq 0 \$((\$CPU_COUNT - 1))); do
        echo "performance" > /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_governor
    done

    # 最终协议栈合闸
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sysctl -w net.ipv4.tcp_fastopen=3
}
EOF

chmod +x package/base-files/files/etc/init.d/matrix_logic

# =========================================================
# 5. 机型精准调优：生成 .config 并按机型注入 sysctl
# =========================================================
SYSCTL_PATH="package/base-files/files/etc/sysctl.conf"
make defconfig

# 判定机型，合闸狂暴参数
if grep -iq "rax3000m-emmc\|xr30-emmc" .config; then
    cat >> $SYSCTL_PATH <<EOF
vm.vfs_cache_pressure=40
vm.dirty_expire_centisecs=1500
vm.dirty_writeback_centisecs=300
EOF
elif grep -iq "360t7\|xr30-nand" .config; then
    cat >> $SYSCTL_PATH <<EOF
kernel.mm.transparent_hugepages.enabled=always
vm.swappiness=10
EOF
elif grep -iq "tr3000v1" .config; then
    cat >> $SYSCTL_PATH <<EOF
vm.vfs_cache_pressure=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
EOF
fi

# =========================================================
# 6. 资产精简与最终锁定
# =========================================================
# 删除冗余插件，腾出算力给核心转发
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_wrtbwmon=y/CONFIG_PACKAGE_wrtbwmon=n/g' .config

# 确保硬件加速模块入库
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_kmod-crypto-aes=y
CONFIG_PACKAGE_kmod-mtk-eth-hw-offload=y
EOF

# 固件标识
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWrt-Matrix-Turbo-6.6.95-By-Gemini'/g" package/base-files/files/etc/openwrt_release

make defconfig
echo "✅ 全量合闸完成，建议配合 GitHub Actions 执行 yes '' | make 编译！"#!/bin/bash

# =========================================================
# 1. 环境预热：拉取最新 Feeds 并强制对齐
# =========================================================
./scripts/feeds update -a && ./scripts/feeds install -a

# =========================================================
# 2. 基因重构：Cortex-A53 暴力指令集优化 (全量对齐)
# =========================================================
# 统一所有地方的编译参数，确保 LSE 原子指令、CRC、Crypto 贯穿始终
sed -i 's/-Os -pipe/-O3 -pipe -march=armv8-a+lse+crc+crypto -mtune=cortex-a53/g' include/target.mk
sed -i 's/-mcpu=cortex-a53/-mcpu=cortex-a53+lse+crc+crypto/g' include/target.mk
sed -i 's/TARGET_CFLAGS += -fno-align-functions/TARGET_CFLAGS += -march=armv8-a+lse+crc+crypto -mtune=cortex-a53/g' include/target.mk

# =========================================================
# 3. 内核秘籍注入：6.6.95 强力合闸 (解决 syncconfig 报错)
# =========================================================
KERNEL_CONF="target/linux/mediatek/filogic/config-6.6"

# 强制替换/追加内核宏，确保依赖项全部激活
update_kernel_config() {
    sed -i "/$1/d" $KERNEL_CONF
    echo "$1=$2" >> $KERNEL_CONF
}

# [原子级同步] 极致利用 1.65GHz
update_kernel_config "CONFIG_ARM64_LSE_ATOMICS" "y"
update_kernel_config "CONFIG_ARM64_USE_LSE_ATOMICS" "y"
# [kTLS 加速]
update_kernel_config "CONFIG_TLS" "y"
update_kernel_config "CONFIG_TLS_DEVICE" "y"
# [硬件引擎驱动]
update_kernel_config "CONFIG_CRYPTO_DEV_SAFEXCEL" "y"
update_kernel_config "CONFIG_NET_MEDIATEK_SOC_WED" "y"
update_kernel_config "CONFIG_NET_MEDIATEK_SOC_PPE" "y"
# [内存折叠与 BPF 加速]
update_kernel_config "CONFIG_ZRAM" "y"
update_kernel_config "CONFIG_ZRAM_DEF_COMP_ZSTD" "y"
update_kernel_config "CONFIG_DEBUG_INFO_BTF" "y"
update_kernel_config "CONFIG_DEBUG_INFO" "n"
update_kernel_config "CONFIG_DYNAMIC_DEBUG" "n"

# =========================================================
# 4. 运行态矩阵：创建流水线隔离脚本 (入库系统启动项)
# =========================================================
mkdir -p package/base-files/files/etc/init.d

cat > package/base-files/files/etc/init.d/matrix_logic <<EOF
#!/bin/sh /etc/rc.common
START=99

boot() {
    # 检测核心数量，自动对齐逻辑断点
    CPU_COUNT=\$(grep -c ^processor /proc/cpuinfo)

    # 唤醒硬件引擎与 kTLS 硬件合闸
    modprobe crypto_safexcel 2>/dev/null
    modprobe tls 2>/dev/null
    echo 1 > /sys/module/tls/parameters/tls_hw 2>/dev/null
    echo 1 > /proc/sys/net/netfilter/nf_flow_table_hw 2>/dev/null

    # 中断号动态获取
    ETH_IRQ=\$(grep -m1 "mtk-network" /proc/interrupts | cut -d: -f1 | tr -d ' ')
    WIFI_IRQ=\$(grep -E "mt7981|mt7986" /proc/interrupts | head -n1 | cut -d: -f1 | tr -d ' ')
    CRYPTO_IRQ=\$(grep -E "safexcel|eip" /proc/interrupts | awk -F: '{print \$1}' | tr -d ' ')

    if [ "\$CPU_COUNT" -eq 4 ]; then
        # [MT7986 四核模式] CPU0,1 搬运 | CPU2,3 计算 (Mask C)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 3 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo c > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo c > "\$x"; done
    else
        # [MT7981 双核模式] CPU0 搬运 | CPU1 计算 (Mask 2)
        for irq in \$ETH_IRQ \$WIFI_IRQ; do echo 1 > "/proc/irq/\$irq/smp_affinity"; done
        for irq in \$CRYPTO_IRQ; do echo 2 > "/proc/irq/\$irq/smp_affinity"; done
        for x in /sys/class/net/*/queues/rx-*/rps_cpus; do echo 2 > "\$x"; done
    fi

    # 流量接力缓冲区优化
    echo 16384 > /proc/sys/net/core/rps_sock_flow_entries
    for rps_flow in /sys/class/net/*/queues/rx-*/rps_flow_cnt; do echo 2048 > "\$rps_flow"; done

    # 锁定巅峰频率 (配合大铜片散热)
    for i in \$(seq 0 \$((\$CPU_COUNT - 1))); do
        echo "performance" > /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_governor
    done

    # 最终协议栈合闸
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sysctl -w net.ipv4.tcp_fastopen=3
}
EOF

chmod +x package/base-files/files/etc/init.d/matrix_logic

# =========================================================
# 5. 机型精准调优：生成 .config 并按机型注入 sysctl
# =========================================================
SYSCTL_PATH="package/base-files/files/etc/sysctl.conf"
make defconfig

# 判定机型，合闸狂暴参数
if grep -iq "rax3000m-emmc\|xr30-emmc" .config; then
    cat >> $SYSCTL_PATH <<EOF
vm.vfs_cache_pressure=40
vm.dirty_expire_centisecs=1500
vm.dirty_writeback_centisecs=300
EOF
elif grep -iq "360t7\|xr30-nand" .config; then
    cat >> $SYSCTL_PATH <<EOF
kernel.mm.transparent_hugepages.enabled=always
vm.swappiness=10
EOF
elif grep -iq "tr3000v1" .config; then
    cat >> $SYSCTL_PATH <<EOF
vm.vfs_cache_pressure=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
EOF
fi

# =========================================================
# 6. 资产精简与最终锁定
# =========================================================
# 删除冗余插件，腾出算力给核心转发
sed -i 's/CONFIG_PACKAGE_luci-app-turboacc=y/CONFIG_PACKAGE_luci-app-turboacc=n/g' .config
sed -i 's/CONFIG_PACKAGE_wrtbwmon=y/CONFIG_PACKAGE_wrtbwmon=n/g' .config

# 确保硬件加速模块入库
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-crypto-hw-safexcel=y
CONFIG_PACKAGE_kmod-crypto-aes=y
CONFIG_PACKAGE_kmod-mtk-eth-hw-offload=y
EOF

# 固件标识
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='ImmortalWrt-Matrix-Turbo-6.6.95-By-Gemini'/g" package/base-files/files/etc/openwrt_release

make defconfig
echo "✅ 全量合闸完成，建议配合 GitHub Actions 执行 yes '' | make 编译！"
