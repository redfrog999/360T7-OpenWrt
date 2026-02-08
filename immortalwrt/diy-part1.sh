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

echo "开始 DIY1 配置……"
echo "========================="

# Uncomment a feed source
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
# sed -i '1i src-git kenzo https://github.com/NicolasMe9907/openwrt-packages' feeds.conf.default
# sed -i '$a src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main' feeds.conf.default
# sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
# sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

# rm -rf target/linux/ramips
# svn export https://github.com/padavanonly/immortalwrt/trunk/target/linux/ramips target/linux/ramips

# 修改系统版本（界面显示）
VERSION=${GITHUB_WORKSPACE}/immortalwrt/version
VERSION_TEXT=$(head -n 1 ${VERSION} | tr -d ' \r\n')
if [ -n "$VERSION_TEXT" ]; then
	sed -i "/^VERSION_NUMBER:=.*SNAPSHOT/s/SNAPSHOT/${VERSION_TEXT}/" include/version.mk
fi

#!/bin/bash
# ---------------------------------------------------------
# 物理獵人：Rust 環境變量加速 (中科大源)
# ---------------------------------------------------------
echo "Setting up Rust mirror..."
# 寫入環境變量到 GitHub Action 全局環境
echo "RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static" >> $GITHUB_ENV
echo "RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup" >> $GITHUB_ENV

# 物理修改 OpenWrt 下載源優先級 (將中科大源插到最前面)
sed -i 's/https:\/\/sources.openwrt.org/https:\/\/mirrors.ustc.edu.cn\/openwrt\/sources/g' include/download.mk

echo "========================="
echo " DIY1 配置完成……"
