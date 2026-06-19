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
    download_url="$1"
    download_output="$2"
    download_tmp="$download_output.tmp.$$"
    rm -f "$download_tmp"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --connect-timeout 20 "$download_url" -o "$download_tmp"; then
            mv "$download_tmp" "$download_output"
            return 0
        fi
        if curl -kfsSL --retry 2 --connect-timeout 20 "$download_url" -o "$download_tmp"; then
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
    [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}

install_passwall_nft_kmods() {
    [ "$(detect_pkg_mgr)" = "apk" ] || return 0

    missing=""
    for pkg in kmod-nft-socket kmod-nft-tproxy; do
        apk info -e "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
    done

    [ -n "$missing" ] || return 0

    log "安装 PassWall nftables 透明代理内核依赖:$missing"
    apk update || warn "apk update 失败，继续尝试安装 kmod"
    apk add $missing || die "安装 PassWall nftables 透明代理内核依赖失败，请检查官方软件源和内核版本是否匹配"

    if command -v modprobe >/dev/null 2>&1; then
        modprobe nft_socket >/dev/null 2>&1 || true
        modprobe nft_tproxy >/dev/null 2>&1 || true
    fi
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
