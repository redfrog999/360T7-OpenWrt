#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# Modify hostname
#sed -i 's/ImmortalWrt/rax3000m_256m/g' package/base-files/files/bin/config_generate

#修改wifi名称（mtwifi-cfg）
#sed -i 's/ImmortalWrt-2.4G/OpenWrt/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
#sed -i 's/ImmortalWrt-5G/OpenWrt5G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# drop mosdns and v2ray-geodata packages that come with the source
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f

git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

#Install TinyFileManager
#git clone --depth 1 --branch master --single-branch --no-checkout https://github.com/muink/luci-app-tinyfilemanager.git package/luci-app-tinyfilemanager

echo '替换golang到1.22.x'
rm -rf feeds/packages/lang/golang
git clone -b 22.x --single-branch https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
echo '=========Replace golang OK!========='

#echo '替换Passwall软件'
#rm -rf feeds/luci/applications/luci-app-passwall
#git clone -b main --single-branch https://github.com/xiaorouji/openwrt-passwall feeds/luci/applications/luci-app-passwall
#mv feeds/luci/applications/luci-app-passwall/luci-app-passwall/* feeds/luci/applications/luci-app-passwall/
#rm -rf feeds/luci/applications/luci-app-passwall/luci-app-passwall
#echo '=========Replace passwall source OK!========='

#echo '修改Passwall检测规则'
#sed -i 's/socket" "iptables-mod-//g' feeds/luci/applications/luci-app-passwall/root/usr/share/passwall/app.sh
#echo '=========ALTER passwall denpendcies check OK!========='

#echo '开启sing-box的CGO标记'
#sed -i 's/CGO_ENABLED=0/CGO_ENABLED=1/g' feeds/passwall/sing-box/Makefile
#echo '=========Enable sing-box CGO FLAG OK !========='
