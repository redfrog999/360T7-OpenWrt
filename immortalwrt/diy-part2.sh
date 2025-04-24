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

# 默认IP由1.1修改为15.1
sed -i 's/192.168.1.1/192.168.15.1/g' package/base-files/files/bin/config_generate

# 最大连接数修改为65535
# sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# 修复上移下移按钮翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

# ------------------PassWall 科学上网--------------------------
# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box,pdnsd-alt,chinadns-ng,dns2socks,dns2tcp,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview}
# 核心库
git clone https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages
rm -rf package/passwall-packages/{shadowsocks-rust,v2ray-geodata}
merge_package v5 https://github.com/sbwml/openwrt_helloworld package/passwall-packages shadowsocks-rust v2ray-geodata
# app
rm -rf feeds/luci/applications/{luci-app-passwall,luci-app-ssr-libev-server}
# git clone https://github.com/lwb1978/openwrt-passwall package/passwall-luci
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall-luci
# ------------------------------------------------------------

# Passwall2
rm -rf feeds/luci/applications/luci-app-passwall2
git clone https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2

# 优化socat中英翻译
sed -i 's/仅IPv6/仅 IPv6/g' package/feeds/luci/luci-app-socat/po/zh_Hans/socat.po

# SmartDNS
rm -rf feeds/luci/applications/luci-app-smartdns
git clone https://github.com/lwb1978/luci-app-smartdns package/luci-app-smartdns
# 替换immortalwrt 软件仓库smartdns版本为官方最新版
rm -rf feeds/packages/net/smartdns
cp -rf ${GITHUB_WORKSPACE}/patch/smartdns feeds/packages/net

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
git clone --depth=1 -b js https://github.com/sirpdboy/luci-theme-kucat package/luci-theme-kucat
git clone --depth=1 -b main https://github.com/sirpdboy/luci-app-advancedplus  package/luci-app-advancedplus

# golang 1.24
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

# TTYD设置
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init

#./scripts/feeds update -a
#./scripts/feeds install -a

make defconfig

echo "========================="
echo " DIY2 配置完成……"
