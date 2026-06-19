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

run_passwall_postinst_basics() {
    [ -s /lib/functions.sh ] || return 0
    # shellcheck disable=SC1091
    . /lib/functions.sh

    for pkgname in \
        luci-app-passwall luci-i18n-passwall-zh-cn \
        xray-core sing-box hysteria chinadns-ng dns2socks tcping geoview \
        v2ray-geoip v2ray-geosite
    do
        export root=""
        export pkgname
        add_group_and_user >/dev/null 2>&1 || true
        default_postinst >/dev/null 2>&1 || true
    done
}

ensure_passwall_defaults() {
    if [ ! -s /etc/config/passwall ] && [ -s /usr/share/passwall/0_default_config ]; then
        mkdir -p /etc/config
        cp /usr/share/passwall/0_default_config /etc/config/passwall
    fi

    command -v uci >/dev/null 2>&1 || return 0
    if ! uci -q show passwall 2>/dev/null | grep -q '=global_app'; then
        uci -q add passwall global_app >/dev/null 2>&1 || true
    fi

    uci -q set passwall.@global_app[0].xray_file="/usr/bin/xray" || true
    uci -q set passwall.@global_app[0].sing_box_file="/usr/bin/sing-box" || true
    uci -q set passwall.@global_app[0].hysteria_file="/usr/bin/hysteria" || true
    uci -q set passwall.@global_app[0].geoview_file="/usr/bin/geoview" || true
    uci -q commit passwall || true
}

verify_passwall_cores() {
    missing=""
    for bin in /usr/bin/xray /usr/bin/sing-box; do
        [ -x "$bin" ] || missing="$missing $bin"
    done

    [ -z "$missing" ] || die "PassWall 核心安装不完整，缺少:$missing"
}

install_passwall_apks() {
    IPKG_NO_SCRIPT=1 apk add --allow-untrusted "$@"
    run_passwall_postinst_basics
    ensure_passwall_defaults
    install_passwall_nft_kmods
    verify_passwall_cores
    refresh_luci
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
