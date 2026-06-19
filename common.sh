#!/bin/sh
set -eu

PROJECT_NAME="openwrt-official-one-click"
CACHE_DIR="/usr/lib/$PROJECT_NAME"
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-8}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-25}"

log() {
    printf '%s\n' "==> $*"
}

warn() {
    printf '%s\n' "[WARN] $*" >&2
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

need_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户执行"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

detect_pkg_mgr() {
    if command -v apk >/dev/null 2>&1; then
        printf '%s\n' "apk"
    elif command -v opkg >/dev/null 2>&1; then
        printf '%s\n' "opkg"
    else
        die "没有检测到 apk 或 opkg"
    fi
}

pkg_update() {
    pkg_mgr="$(detect_pkg_mgr)"
    case "$pkg_mgr" in
        apk) apk update ;;
        opkg) opkg update ;;
    esac
}

pkg_install_one() {
    pkg="$1"
    pkg_mgr="$(detect_pkg_mgr)"
    case "$pkg_mgr" in
        apk) apk add "$pkg" ;;
        opkg) opkg install "$pkg" ;;
    esac
}

download_file() {
    download_url="$1"
    download_output="$2"
    download_tmp="$download_output.tmp.$$"
    rm -f "$download_tmp"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --retry 2 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" "$download_url" -o "$download_tmp"; then
            mv "$download_tmp" "$download_output"
            return 0
        fi
        if curl -kfsSL --retry 1 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" "$download_url" -o "$download_tmp"; then
            mv "$download_tmp" "$download_output"
            return 0
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -qO "$download_tmp" "$download_url"; then
            mv "$download_tmp" "$download_output"
            return 0
        fi
        if wget --help 2>&1 | grep -q -- '--no-check-certificate'; then
            if wget --no-check-certificate -qO "$download_tmp" "$download_url"; then
                mv "$download_tmp" "$download_output"
                return 0
            fi
        fi
    fi

    rm -f "$download_tmp"
    return 1
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /var/run/luci-indexcache 2>/dev/null || true
    rm -f /tmp/luci-indexcache.* 2>/dev/null || true
    rm -rf /tmp/luci-modulecache 2>/dev/null || true
}

script_dir() {
    CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

run_script() {
    name="$1"
    shift
    dir="$(script_dir)"
    script="$dir/$name"
    [ -f "$script" ] || die "缺少脚本: $script"
    sh "$script" "$@"
}
