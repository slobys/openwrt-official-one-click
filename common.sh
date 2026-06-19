#!/bin/sh
set -eu

PROJECT_NAME="openwrt-official-one-click"
CACHE_DIR="/usr/lib/$PROJECT_NAME"

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
    url="$1"
    output="$2"
    tmp="$output.tmp.$$"
    rm -f "$tmp"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$tmp"; then
            mv "$tmp" "$output"
            return 0
        fi
        if curl -kfsSL --retry 2 --connect-timeout 20 "$url" -o "$tmp"; then
            mv "$tmp" "$output"
            return 0
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -qO "$tmp" "$url"; then
            mv "$tmp" "$output"
            return 0
        fi
        if wget --help 2>&1 | grep -q -- '--no-check-certificate'; then
            if wget --no-check-certificate -qO "$tmp" "$url"; then
                mv "$tmp" "$output"
                return 0
            fi
        fi
    fi

    rm -f "$tmp"
    return 1
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /var/run/luci-indexcache 2>/dev/null || true
    [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
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
