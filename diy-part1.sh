#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages' >>feeds.conf.default
# echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
# echo 'src-git adguardhome https://github.com/AdguardTeam/AdGuardHome' >>feeds.conf.default
# echo 'src-git openclash https://github.com/vernesong/OpenClash' >>feeds.conf.default

rm -rf package/passwall
git clone https://github.com/xiaorouji/openwrt-passwall package/passwall
rm -rf package/openclash
git clone https://github.com/vernesong/OpenClash.git package/openclash
rm -rf package/AdguardHome
git clone https://github.com/AdguardTeam/AdguardHome package/AdguardHome

# 添加插件源码
# sed -i '$a src-git-full kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
