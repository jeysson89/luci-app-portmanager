#!/bin/sh
# ---------------------------------------------------------------------------
#  install.sh - установщик приложения luci-app-portmanager
#
#  Запуск на роутере:
#      wget -qO- https://raw.githubusercontent.com/jeysson89/luci-app-portmanager/main/install.sh | sh
#
#  Или с локальным файлом:
#      sh install.sh /tmp/luci-app-portmanager-1.0.0-r1.apk
# ---------------------------------------------------------------------------

REPO="jeysson89/luci-app-portmanager"
VER="1.0.0-r1"
TAG="v1.0.0"
PKG_NAME="luci-app-portmanager"

msg()   { printf '\033[32m[+]\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m[!]\033[0m %s\n' "$1"; }
fail()  { printf '\033[31m[x]\033[0m %s\n' "$1"; exit 1; }

[ "$(id -un)" = "root" ] || fail "Запускайте от root"

# --- зависимости ---------------------------------------------------------
for dep in luci-base rpcd-mod-ucode ip-bridge; do
	apk info -e "$dep" >/dev/null 2>&1 || {
		msg "Устанавливаю зависимость: $dep"
		apk update >/dev/null 2>&1
		apk add "$dep" || fail "Не удалось установить $dep"
	}
done

# --- установка приложения ------------------------------------------------
if [ -n "$1" ] && [ -f "$1" ]; then
	PKG="$1"
	msg "Использую локальный пакет: $PKG"
else
	PKG="/tmp/${PKG_NAME}-${VER}.apk"
	URL="https://github.com/${REPO}/releases/download/${TAG}/${PKG_NAME}-${VER}.apk"
	msg "Скачиваю $URL"
	wget -qO "$PKG" "$URL" || curl -sL -o "$PKG" "$URL" || fail "Не удалось скачать пакет (укажите путь к .apk аргументом)"
fi

apk add --allow-untrusted "$PKG" || fail "Установка пакета не удалась"

# --- доводка (на случай, если post-install не отработал) -----------------
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

msg "Готово! Откройте в браузере:"
LAN_IP=$(uci -q get network.lan.ipaddr || echo 192.168.1.1)
LAN_IP="${LAN_IP%%/*}"
echo "   http://${LAN_IP}/cgi-bin/luci/admin/network/portmanager"
