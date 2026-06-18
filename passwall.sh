#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

GH_API="https://api.github.com/repos/Openwrt-Passwall/openwrt-passwall/releases/latest"
SF_PROJECT="openwrt-passwall-build"
SF_BASE="https://sourceforge.net/projects/$SF_PROJECT/files"
LOCAL_DIR="${LOCAL_DIR:-/tmp/passwall}"
MODE="${1:-online}"

need_root
need_cmd grep
need_cmd sed
need_cmd awk
need_cmd basename

pkg_mgr="$(detect_pkg_mgr)"
[ "$pkg_mgr" = "apk" ] || die "当前脚本主要适配 OpenWrt 25.12+ 的 apk 环境"

[ -f /etc/openwrt_release ] || die "未检测到 /etc/openwrt_release"
# shellcheck disable=SC1091
. /etc/openwrt_release

ARCH="${DISTRIB_ARCH:-}"
REL_RAW="${DISTRIB_RELEASE:-}"
[ -n "$ARCH" ] || ARCH="$(apk --print-arch 2>/dev/null || true)"
[ -n "$ARCH" ] || die "无法识别 CPU 架构"

case "$REL_RAW" in
    25.*|"") RELEASE_DIR="25.12" ;;
    *) die "当前系统版本 $REL_RAW 暂按 25.12/apk 之外处理，建议先用官方 25.12+ 固件" ;;
esac

PACKAGE_DIR="releases/packages-$RELEASE_DIR/$ARCH"
WORK_DIR="/tmp/passwall-download.$$"

cleanup() {
    [ -n "${KEEP_WORK_DIR:-}" ] || rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

valid_pkg_file() {
    file="$1"
    [ -s "$file" ] || return 1
    [ "$(wc -c < "$file")" -gt 1024 ] || return 1
    if head -c 512 "$file" 2>/dev/null | tr 'A-Z' 'a-z' | grep -qE '<html|<!doctype|sourceforge'; then
        return 1
    fi
    return 0
}

install_local_apks() {
    dir="$1"
    set -- "$dir"/*.apk
    [ -e "$1" ] || die "没有找到本地 APK: $dir/*.apk"
    log "安装本地 APK: $dir"
    apk add --allow-untrusted "$@"
    refresh_luci
    log "PassWall 本地 APK 安装完成"
}

if [ "$MODE" = "--local" ] || [ "$MODE" = "local" ]; then
    install_local_apks "$LOCAL_DIR"
    exit 0
fi

log "System release: ${REL_RAW:-unknown}"
log "Arch: $ARCH"
log "Package dir: $PACKAGE_DIR"
log "如果 SourceForge 在软路由上很慢，可以先用 Windows 离线脚本下载，再上传到 /tmp/passwall 后执行 --passwall-local"

mkdir -p "$WORK_DIR"

fetch_text_to_file() {
    url="$1"
    file="$2"
    download_file "$url" "$file"
}

download_github_luci_asset() {
    regex="$1"
    outdir="$2"
    api_file="$WORK_DIR/github-latest.json"
    fetch_text_to_file "$GH_API" "$api_file" || return 1
    url="$(sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' "$api_file" \
        | grep -E "$regex" \
        | head -n1 || true)"
    [ -n "$url" ] || return 1

    filename="$(basename "$url" | sed 's/%2B/+/g')"
    output="$outdir/$filename"
    log "GitHub 下载: $filename"
    download_file "$url" "$output" || download_file "https://gh-proxy.com/$url" "$output" || return 1
    valid_pkg_file "$output"
}

latest_sf_file() {
    repo="$1"
    regex="$2"
    tmp="$WORK_DIR/sf-$repo.txt"
    rss_url="https://sourceforge.net/projects/$SF_PROJECT/rss?path=/$PACKAGE_DIR/$repo"
    folder_url="$SF_BASE/$PACKAGE_DIR/$repo/"

    if fetch_text_to_file "$rss_url" "$tmp"; then
        name="$(grep -oE '[A-Za-z0-9._+-]+\.apk' "$tmp" | grep -E "$regex" | head -n1 || true)"
        if [ -n "$name" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi

    if fetch_text_to_file "$folder_url" "$tmp"; then
        name="$(grep -oE '[A-Za-z0-9._+-]+\.apk' "$tmp" | grep -E "$regex" | head -n1 || true)"
        if [ -n "$name" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi

    return 1
}

download_sf_package() {
    repo="$1"
    filename="$2"
    outdir="$3"
    output="$outdir/$filename"

    for url in \
        "https://master.dl.sourceforge.net/project/$SF_PROJECT/$PACKAGE_DIR/$repo/$filename" \
        "https://downloads.sourceforge.net/project/$SF_PROJECT/$PACKAGE_DIR/$repo/$filename" \
        "https://sourceforge.net/projects/$SF_PROJECT/files/$PACKAGE_DIR/$repo/$filename/download"
    do
        rm -f "$output"
        if download_file "$url" "$output" && valid_pkg_file "$output"; then
            return 0
        fi
        warn "当前下载源异常，尝试下一个源: $filename"
    done

    return 1
}

download_target() {
    title="$1"
    repo="$2"
    regex="$3"
    outdir="$4"

    log "匹配: $title"
    filename="$(latest_sf_file "$repo" "$regex" || true)"
    [ -n "$filename" ] || die "没有找到 $title，请检查上游是否发布 $ARCH / $RELEASE_DIR 构建"
    log "下载: $filename"
    download_sf_package "$repo" "$filename" "$outdir" || die "下载失败: $filename"
}

download_dir="$WORK_DIR/apks"
mkdir -p "$download_dir"

log "优先从 GitHub Release 下载 PassWall 主程序和中文包"
download_github_luci_asset '/25\.12(%2B|\+)_luci-app-passwall-[^/"]+\.apk$' "$download_dir" \
    || download_target "luci-app-passwall" "passwall_luci" '^luci-app-passwall-[0-9].*\.apk$' "$download_dir"
download_github_luci_asset '/25\.12(%2B|\+)_luci-i18n-passwall-zh-cn-[^/"]+\.apk$' "$download_dir" \
    || download_target "luci-i18n-passwall-zh-cn" "passwall_luci" '^luci-i18n-passwall-zh-cn-[0-9].*\.apk$' "$download_dir"

log "下载常用运行依赖"
download_target "chinadns-ng" "passwall_packages" '^chinadns-ng-[0-9].*\.apk$' "$download_dir"
download_target "dns2socks" "passwall_packages" '^dns2socks-[0-9].*\.apk$' "$download_dir"
download_target "tcping" "passwall_packages" '^tcping-[0-9].*\.apk$' "$download_dir"
download_target "geoview" "passwall_packages" '^geoview-[0-9].*\.apk$' "$download_dir"
download_target "xray-core" "passwall_packages" '^xray-core-[0-9].*\.apk$' "$download_dir"
download_target "sing-box" "passwall_packages" '^sing-box-[0-9].*\.apk$' "$download_dir"
download_target "hysteria" "passwall_packages" '^hysteria-[0-9].*\.apk$' "$download_dir"
download_target "v2ray-geoip" "passwall_packages" '^v2ray-geoip-[0-9].*\.apk$' "$download_dir"
download_target "v2ray-geosite" "passwall_packages" '^v2ray-geosite-[0-9].*\.apk$' "$download_dir"

log "更新 apk 索引"
apk update || warn "apk update 失败，将继续尝试安装本地 APK"

log "安装 PassWall APK"
apk add --allow-untrusted "$download_dir"/*.apk
refresh_luci

NEW_VER="$(apk info -a luci-app-passwall 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
log "安装后版本: ${NEW_VER:-unknown}"
log "PassWall 安装完成"
