#
# Copyright (C) 2026 luci-app-portmanager contributors
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-portmanager
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=luci-app-portmanager contributors
PKG_ARCH:=all

LUCI_TITLE:=Управление портами — включение/отключение, MAC, Torch
LUCI_DESCRIPTION:=Приложение LuCI для управления портами роутера: \
	включение и отключение (Ethernet и Wi-Fi AP), список устройств с MAC-адресами \
	за каждым портом (bridge FDB, ARP, DHCP), безопасная очистка MAC-таблиц \
	(только LAN, без затрагивания WAN) и удаление отдельных записей, \
	монитор активных соединений (Torch) с фильтрами по порту и по устройству. \
	Поддерживает netdev/DSA, legacy swconfig и Wi-Fi точки доступа.
LUCI_DEPENDS:=+luci-base +rpcd-mod-ucode +ip-bridge
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
