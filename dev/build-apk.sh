#!/bin/sh
# Build the luci-app-portmanager package (apk v3) with the static apk of Alpine.
# Usage: build-apk.sh <root-dir> <output-file>
# Expects /tmp/post-install.sh to exist (dev/post-install.sh uploaded beforehand).
set -e

ROOT="${1:-/tmp/pkgroot}"
OUT="${2:-/tmp/luci-app-portmanager-1.0.0-r1.apk}"
APK=/tmp/apkstatic/sbin/apk.static

# the static apk of Alpine is used because it implements "apk mkpkg"
if [ ! -x "$APK" ]; then
	echo "== fetching the static apk of Alpine (apk-tools-static)"
	cd /tmp || exit 1
	curl -s -m 900 -o /tmp/apk-tools-static.apk \
		"https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64/apk-tools-static-3.0.8-r0.apk" || {
		echo "download failed"; exit 1; }
	rm -rf /tmp/apkstatic && mkdir -p /tmp/apkstatic
	apk extract --allow-untrusted --destination /tmp/apkstatic /tmp/apk-tools-static.apk >/dev/null 2>&1
	rm -f /tmp/apk-tools-static.apk
fi

[ -x "$APK" ] || { echo "static apk not found: $APK"; exit 1; }
[ -d "$ROOT" ] || { echo "package root not found: $ROOT"; exit 1; }

# file modes
find "$ROOT" -type d -exec chmod 0755 {} \; 2>/dev/null || true
chmod 0755 "$ROOT" 2>/dev/null || true
chmod 0755 "$ROOT/usr/share/rpcd/ucode/portmanager" 2>/dev/null || true
chmod 0644 "$ROOT"/usr/share/rpcd/acl.d/*.json 2>/dev/null || true
chmod 0644 "$ROOT"/usr/share/luci/menu.d/*.json 2>/dev/null || true
chmod 0644 "$ROOT"/www/luci-static/resources/view/portmanager/*.js 2>/dev/null || true

INSTALLED_SIZE=$(du -sk "$ROOT" | awk '{print $1 * 1024}')

rm -f "$OUT"

"$APK" mkpkg \
	--files "$ROOT" \
	--info "name:luci-app-portmanager" \
	--info "version:1.0.0-r1" \
	--info "arch:noarch" \
	--info "description:LuCI application for LAN/WAN port management: enable/disable ports, per-port MAC lists, safe MAC table flush, conntrack torch with port and device filters" \
	--info "url:https://github.com/jeysson89/luci-app-portmanager" \
	--info "license:GPL-3.0-or-later" \
	--info "maintainer:luci-app-portmanager contributors" \
	--info "depends:luci-base rpcd-mod-ucode ip-bridge" \
	--script "post-install:/tmp/post-install.sh" \
	--sign /tmp/luci-app-portmanager.rsa \
	--output "$OUT"

ls -la "$OUT"
echo "== package info"
"$APK" adbdump "$OUT" 2>/dev/null | head -40
