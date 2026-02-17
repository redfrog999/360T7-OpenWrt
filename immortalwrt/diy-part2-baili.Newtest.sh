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

#!/bin/bash

# --- [ 1. eMMC 物理分区暴力挂载补丁 ] ---
# 强制注入 rc.local，解决 fstools 找不到 rootfs_data 的“失忆症”
cat << 'EOF' > package/base-files/files/etc/rc.local
# 如果发现 overlay 依然挂在内存 tmpfs，说明物理分区未格式化
if [ "$(mount | grep 'overlayfs:/tmp/root')" ]; then
    # 尝试寻找 eMMC 的大容量数据分区（通常是最后一个）
    TARGET_PART=$(lsblk -l | grep mmcblk0 | tail -n 1 | awk '{print "/dev/"$1}')
    if [ -b "$TARGET_PART" ]; then
        # 强制执行物理装修：格式化并打上 rootfs_data 标签
        /usr/sbin/mkfs.f2fs -f -l rootfs_data "$TARGET_PART" && reboot
    fi
fi
exit 0
EOF

# --- [ 2. RPS/RFS 动态分型优化矩阵 ] ---
# 针对 MT7986 (4核) 和 MT7981 (2核) 进行中断与流控的物理隔离
cat << 'EOF' > package/base-files/files/etc/init.d/rps_optimize
#!/bin/sh /etc/rc.common
START=99

start() {
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    
    # 强制合闸：设置 RFS 总表容量
    echo "32768" > /proc/sys/net/core/rps_sock_flow_entries
    
    if [ "$CPU_CORES" -eq 4 ]; then
        # [MT7986 四核专用]：将中断留在 CPU0，将 RPS 负载分发到 CPU1,2,3 (掩码 E, 即 1110)
        MASK="e"
    else
        # [MT7981 双核专用]：将中断留在 CPU0，将负载分发到 CPU1 (掩码 2, 即 10)
        MASK="2"
    fi

    # 遍历所有物理网卡，注入电子脚镣
    for dev in /sys/class/net/eth* /sys/class/net/lan* /sys/class/net/wan*; do
        [ -d "$dev" ] || continue
        echo "$MASK" > "$dev/queues/rx-0/rps_cpus"
        echo "4096" > "$dev/queues/rx-0/rps_flow_cnt"
    done
}
EOF

chmod +x package/base-files/files/etc/init.d/rps_optimize
# 物理合闸：加入开机自启
ln -sf ../init.d/rps_optimize package/base-files/files/etc/rc.d/S99rps_optimize

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
