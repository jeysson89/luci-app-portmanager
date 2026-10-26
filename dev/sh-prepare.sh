#!/bin/sh
# prepare the staging area for the package build
rm -rf /tmp/pkgroot
mkdir -p /tmp/pkgroot
rm -f /tmp/build-apk.sh /tmp/post-install.sh /tmp/apk-tools-static.apk /tmp/luci-app-portmanager-*.apk
exit 0
