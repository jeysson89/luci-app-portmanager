#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build an opkg .ipk package (OpenWrt 23.05+/24.10) from files/ without the SDK.

Creates: dist/luci-app-portmanager_<version>_all.ipk
(an ar archive with debian-binary / control.tar.gz / data.tar.gz)
"""
import io, os, sys, tarfile, time, stat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = os.path.join(ROOT, "files")
DIST = os.path.join(ROOT, "dist")

PKG_NAME = "luci-app-portmanager"
PKG_VERSION = "1.0.0-r1"
PKG_TAG = "v1.0.0"
PKG_ARCH = "all"
PKG_MAINTAINER = "luci-app-portmanager contributors"
PKG_LICENSE = "GPL-3.0-or-later"
PKG_URL = "https://github.com/jeysson89/luci-app-portmanager"
PKG_DEPENDS = "luci-base, rpcd-mod-ucode, ip-bridge"
PKG_DESCRIPTION = (
    "LuCI application for LAN/WAN port management: enable/disable ports,\n"
    "per-port MAC lists, safe MAC table flush (WAN and permanent entries are\n"
    "never touched) and conntrack torch with port and device filters."
)

POSTINST = """#!/bin/sh
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart 2>/dev/null
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null
exit 0
"""


def add_to_tar(tf, arcname, body=None, mode=None, path=None):
    ti = tarfile.TarInfo(arcname)
    ti.uid = 0
    ti.gid = 0
    ti.uname = ""
    ti.gname = ""
    ti.mtime = int(time.time())
    if body is None and path is None:
        ti.type = tarfile.DIRTYPE
        ti.mode = mode if mode is not None else 0o755
        tf.addfile(ti)
        return
    if body is not None:
        ti.size = len(body)
        ti.mode = mode if mode is not None else 0o644
        tf.addfile(ti, io.BytesIO(body))
        return
    with open(path, "rb") as f:
        data = f.read()
    ti.size = len(data)
    ti.mode = mode if mode is not None else (0o755 if os.access(path, os.X_OK) else 0o644)
    tf.addfile(ti, io.BytesIO(data))


def add_tree(tf, base):
    base_abs = os.path.join(FILES, base)
    for dirpath, dirnames, filenames in os.walk(base_abs):
        dirnames.sort()
        for name in sorted(dirnames):
            full = os.path.join(dirpath, name)
            arc = base + os.path.relpath(full, base_abs).replace("\\", "/")
            add_to_tar(tf, arc + "/", mode=0o755)
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            arc = base + os.path.relpath(full, base_abs).replace("\\", "/")
            add_to_tar(tf, arc, path=full)


def gz_bytes(builder):
    buf = io.BytesIO()
    # inner archives must be real gzip streams ("*.tar.gz")
    with tarfile.open(fileobj=buf, mode="w:gz", format=tarfile.GNU_FORMAT) as tf:
        builder(tf)
    return buf.getvalue()


def main():
    os.makedirs(DIST, exist_ok=True)

    installed_size = sum(
        os.path.getsize(os.path.join(dp, f))
        for dp, _, fs in os.walk(FILES) for f in fs
    )
    control = (
        "Package: %s\n"
        "Version: %s\n"
        "Depends: %s\n"
        "Architecture: %s\n"
        "Section: luci\n"
        "Maintainer: %s\n"
        "License: %s\n"
        "Source: %s\n"
        "SourceName: %s\n"
        "Installed-Size: %d\n"
        "Description: %s\n"
        % (PKG_NAME, PKG_VERSION, PKG_DEPENDS, PKG_ARCH, PKG_MAINTAINER,
           PKG_LICENSE, PKG_URL, PKG_NAME, installed_size // 1024 + 1,
           PKG_DESCRIPTION.replace("\n", "\n "))
    )
    postinst = POSTINST.encode("utf-8")

    def control_builder(tf):
        add_to_tar(tf, "./control", body=control.encode("utf-8"), mode=0o644)
        add_to_tar(tf, "./postinst", body=postinst, mode=0o755)

    def data_builder(tf):
        add_to_tar(tf, "./", mode=0o755)
        base_abs = FILES
        for dirpath, dirnames, filenames in os.walk(base_abs):
            dirnames.sort()
            for name in sorted(dirnames):
                full = os.path.join(dirpath, name)
                arc = "./" + os.path.relpath(full, base_abs).replace("\\", "/") + "/"
                add_to_tar(tf, arc, mode=0o755)
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                arc = "./" + os.path.relpath(full, base_abs).replace("\\", "/")
                add_to_tar(tf, arc, path=full)

    control_gz = gz_bytes(control_builder)
    data_gz = gz_bytes(data_builder)

    def ar_header(name, size):
        hdr = ("%s" % name).ljust(16).encode()
        hdr += ("%d" % int(time.time())).ljust(12).encode()
        hdr += b"0".ljust(6)
        hdr += b"0".ljust(6)
        hdr += b"100644".ljust(8)
        hdr += ("%d" % size).ljust(10).encode()
        hdr += b"\x60\n"
        assert len(hdr) == 60
        return hdr

    out_name = "%s_%s_%s.ipk" % (PKG_NAME, PKG_VERSION, PKG_ARCH)
    out = os.path.join(DIST, out_name)
    # modern OpenWrt ipk: a gzipped tar wrapping three members,
    # names carry a "./" prefix (same as the official buildroot)
    with tarfile.open(out, mode="w:gz", format=tarfile.GNU_FORMAT) as pkg:
        def outer(name, body, mode=0o644):
            ti = tarfile.TarInfo(name)
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = ""
            ti.mtime = int(time.time())
            ti.size = len(body)
            ti.mode = mode
            pkg.addfile(ti, io.BytesIO(body))
        outer("./debian-binary", b"2.0\n")
        outer("./data.tar.gz", data_gz)
        outer("./control.tar.gz", control_gz)

    print("built %s (%d KB)" % (out_name, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    sys.exit(main())
