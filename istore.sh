#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

ISTORE_INSTALLER_URL="${ISTORE_INSTALLER_URL:-https://github.com/linkease/openwrt-app-actions/raw/main/applications/luci-app-systools/root/usr/share/systools/istore-reinstall.run}"
tmp="/tmp/istore-reinstall.run"

detect_arch() {
    machine="$(uname -m 2>/dev/null || true)"
    case "$machine" in
        x86_64|amd64) printf '%s\n' "x86_64"; return 0 ;;
        aarch64|arm64) printf '%s\n' "arm64"; return 0 ;;
    esac

    if command -v apk >/dev/null 2>&1; then
        pkg_arch="$(apk --print-arch 2>/dev/null || true)"
        case "$pkg_arch" in
            x86_64) printf '%s\n' "x86_64"; return 0 ;;
            aarch64*|arm64*) printf '%s\n' "arm64"; return 0 ;;
        esac
    fi

    if command -v opkg >/dev/null 2>&1; then
        pkg_arch="$(
            opkg print-architecture 2>/dev/null | awk '
                $2 == "x86_64" || $2 ~ /^aarch64/ || $2 ~ /^arm64/ {
                    print $2
                    exit
                }
            ' || true
        )"
        case "$pkg_arch" in
            x86_64) printf '%s\n' "x86_64"; return 0 ;;
            aarch64*|arm64*) printf '%s\n' "arm64"; return 0 ;;
        esac
    fi

    return 1
}

arch="$(detect_arch || true)"
[ -n "$arch" ] || die "iStore 官方安装脚本只支持 x86_64 和 arm64 设备"

pkg_mgr="$(detect_pkg_mgr)"
case "$pkg_mgr" in
    apk|opkg) ;;
    *) die "没有检测到支持的软件包管理器" ;;
esac

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    log "安装下载工具 curl"
    pkg_update || warn "软件源更新失败，继续尝试安装 curl"
    pkg_install_one curl || die "安装 curl 失败，请先配置可用软件源"
fi

log "检测到支持架构: $arch"
log "下载 iStore 官方安装脚本"
download_file "$ISTORE_INSTALLER_URL" "$tmp" || die "下载 iStore 安装脚本失败"
[ -s "$tmp" ] || die "下载文件为空: $tmp"
chmod 755 "$tmp"

log "安装 / 更新 iStore"
sh "$tmp"
refresh_luci
log "iStore 安装完成，请在 LuCI 菜单中查看 iStore / 软件中心"
