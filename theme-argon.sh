#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root
pkg_mgr="$(detect_pkg_mgr)"
[ "$pkg_mgr" = "apk" ] || die "当前主题脚本只适配 OpenWrt 25.12+ 的 apk 环境"

ARGON_URL="${ARGON_URL:-https://github.com/jerrykuku/luci-theme-argon/releases/download/v2.4.3/luci-theme-argon-2.4.3-r20250722.apk}"
tmp="/tmp/luci-theme-argon.apk"

log "下载 Argon 主题"
download_file "$ARGON_URL" "$tmp" || die "下载 Argon 主题失败"
[ -s "$tmp" ] || die "下载文件为空: $tmp"

log "安装 Argon 主题"
apk add --allow-untrusted "$tmp"
refresh_luci
log "Argon 主题安装完成"
