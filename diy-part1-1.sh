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
#sed -i "/helloworld/d" "feeds.conf.default"
#echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"
echo "src-git advancedplus https://github.com/sirpdboy/luci-app-advancedplus.git;main" >> "feeds.conf.default"
echo "src-git kucat https://github.com/sirpdboy/luci-theme-kucat.git;js" >> "feeds.conf.default"
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> "feeds.conf.default"
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> "feeds.conf.default"
echo "src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main" >> "feeds.conf.default"

# Add a feed source
#echo 'src-git alist https://github.com/sbwml/luci-app-alist' >>feeds.conf.default

# 添加插件源码
#sed -i '$a src-git kiddin9 https://github.com/redfrog999/kiddin9-openwrt-packages' feeds.conf.default
sed -i '$a src-git-full kenzo https://github.com/redfrog999/openwrt-packages' feeds.conf.default
#sed -i '$a src-git-full kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
