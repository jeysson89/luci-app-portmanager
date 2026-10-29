#!/bin/sh
# ---------------------------------------------------------------------------
#  install.sh - установщик приложения luci-app-portmanager
#
#  Универсальный: сам определяет менеджер пакетов (apk для OpenWrt 25.x,
#  opkg для 23.05/24.10) и качает подходящий формат.
#
#  Запуск на роутере:
#      wget -qO- https://raw.githubusercontent.com/jeysson89/luci-app-portmanager/main/install.sh | sh
#
#  Или с локальным файлом:
#      sh install.sh /tmp/luci-app-portmanager.apk
# ---------------------------------------------------------------------------

REPO="jeysson89/luci-app-portmanager"
PKG_NAME="luci-app-portmanager"

msg()   { printf '\033[32m[+]\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m[!]\033[0m %s\n' "$1"; }
fail()  { printf '\033[31m[x]\033[0m %s\n' "$1"; exit 1; }

[ "$(id -un)" = "root" ] || fail "Запускайте от root"

if command -v apk >/dev/null 2>&1; then
	PM="apk"
	VER="1.0.0-r1"
	TAG="v1.0.0"
	ASSET="${PKG_NAME}-${VER}.apk"
	for dep in luci-base rpcd-mod-ucode ip-bridge; do
		apk info -e "$dep" >/dev/null 2>&1 || {
			msg "Устанавливаю зависимость: $dep"
			apk update >/dev/null 2>&1
			apk add "$dep" || fail "Не удалось установить $dep"
		}
	done
	# доверие подписи пакета
	KEY="/etc/apk/keys/luci-app-portmanager.rsa.pub"
	KEY_URL="https://raw.githubusercontent.com/${REPO}/main/keys/luci-app-portmanager.rsa.pub"
	if ! grep -q "luci-app-portmanager" "$KEY" 2>/dev/null; then
		msg "Добавляю публичный ключ подписи"
		wget -qO "$KEY" "$KEY_URL" || curl -sL -o "$KEY" "$KEY_URL" || warn "Не удалось скачать ключ подписи — установка продолжится с --allow-untrusted"
		chmod 0644 "$KEY" 2>/dev/null
	fi
else
	if command -v opkg >/dev/null 2>&1; then
		PM="opkg"
		VER="1.0.0-r1"
		TAG="v1.0.0"
		ASSET="${PKG_NAME}_${VER}_all.ipk"
		opkg update >/dev/null 2>&1 || true
	else
		fail "Не найден ни apk, ни opkg — непонятная система"
	fi
fi

msg "Менеджер пакетов: $PM"

# --- установка ------------------------------------------------------------
if [ -n "$1" ] && [ -f "$1" ]; then
	PKG="$1"
	msg "Использую локальный пакет: $PKG"
else
	PKG="/tmp/${ASSET}"
	URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
	msg "Скачиваю $URL"
	wget -qO "$PKG" "$URL" || curl -sL -o "$PKG" "$URL" || fail "Не удалось скачать пакет (укажите путь к .apk/.ipk аргументом)"
fi

if [ "$PM" = "apk" ]; then
	if apk add "$PKG" 2>/dev/null; then
		:
	elif grep -q "luci-app-portmanager" /etc/apk/keys/luci-app-portmanager.rsa.pub 2>/dev/null; then
		fail "Установка не удалась"
	else
		warn "Устанавливаю без проверки подписи (--allow-untrusted)"
		apk add --allow-untrusted "$PKG" || fail "Установка не удалась"
	fi
else
	opkg install "$PKG" || fail "Установка не удалась"
fi

# --- доводка (на случай, если post-install не отработал) -----------------
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

msg "Готово! Откройте в браузере:"
LAN_IP=$(uci -q get network.lan.ipaddr || echo 192.168.1.1)
LAN_IP="${LAN_IP%%/*}"
echo "   http://${LAN_IP}/cgi-bin/luci/admin/network/portmanager"
