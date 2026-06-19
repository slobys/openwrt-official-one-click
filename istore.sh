#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

ISTORE_INSTALLER_URL="${ISTORE_INSTALLER_URL:-https://github.com/linkease/openwrt-app-actions/raw/main/applications/luci-app-systools/root/usr/share/systools/istore-reinstall.run}"
ISTORE_INSTALLER_URLS="${ISTORE_INSTALLER_URLS:-$ISTORE_INSTALLER_URL https://raw.githubusercontent.com/linkease/openwrt-app-actions/main/applications/luci-app-systools/root/usr/share/systools/istore-reinstall.run}"
ISTORE_STORE_REPOS="${ISTORE_STORE_REPOS:-https://istore.linkease.com/repo/all/store https://istore.istoreos.com/repo/all/store https://repo.istoreos.com/repo/all/store}"
installer_file="/tmp/istore-reinstall.run"

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

gzcat_file() {
    file="$1"
    if command -v gzip >/dev/null 2>&1; then
        gzip -dc "$file"
    else
        zcat "$file"
    fi
}

find_pkg_file() {
    packages="$1"
    pkg="$2"

    gzcat_file "$packages" | awk -v pkg="$pkg" '
        $1 == "Package:" && $2 == pkg { in_pkg = 1; next }
        $1 == "Package:" { in_pkg = 0 }
        in_pkg && $1 == "Filename:" { print $2; exit }
    '
}

download_installer() {
    for url in $ISTORE_INSTALLER_URLS; do
        log "尝试下载: $url"
        if download_file "$url" "$installer_file"; then
            return 0
        fi
        warn "下载失败: $url"
    done

    return 1
}

install_from_store_repo() {
    workdir="/tmp/istore-install.$$"
    mkdir -p "$workdir"
    trap 'rm -rf "$workdir"' EXIT INT TERM

    for repo in $ISTORE_STORE_REPOS; do
        packages="$workdir/Packages.gz"
        store_ipk="$workdir/luci-app-store.ipk"
        is_opkg="/tmp/is-opkg"

        log "尝试 iStore 仓库: $repo"
        download_file "$repo/Packages.gz" "$packages" || {
            warn "下载 Packages.gz 失败: $repo"
            continue
        }

        store_file="$(find_pkg_file "$packages" luci-app-store || true)"
        [ -n "$store_file" ] || {
            warn "仓库里没有找到 luci-app-store: $repo"
            continue
        }

        download_file "$repo/$store_file" "$store_ipk" || {
            warn "下载 luci-app-store 失败: $repo/$store_file"
            continue
        }

        cat "$store_ipk" | tar -xzO ./data.tar.gz | tar -xzO ./bin/is-opkg > "$is_opkg" || {
            warn "提取 is-opkg 失败"
            continue
        }
        [ -s "$is_opkg" ] || {
            warn "is-opkg 文件为空"
            continue
        }

        chmod 755 "$is_opkg"
        "$is_opkg" update
        "$is_opkg" install --force-reinstall luci-lib-taskd luci-lib-xterm
        "$is_opkg" install --force-reinstall luci-app-store
        [ -s "/etc/init.d/tasks" ] || "$is_opkg" install --force-reinstall taskd
        [ -s "/usr/lib/lua/luci/cbi.lua" ] || "$is_opkg" install luci-compat >/dev/null 2>&1 || true
        return 0
    done

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
if download_installer; then
    [ -s "$installer_file" ] || die "下载文件为空: $installer_file"
    chmod 755 "$installer_file"

    log "安装 / 更新 iStore"
    sh "$installer_file"
else
    warn "官方安装脚本下载失败，改用 iStore 仓库直装"
    install_from_store_repo || die "iStore 仓库直装失败"
fi
refresh_luci
log "iStore 安装完成，请在 LuCI 菜单中查看 iStore / 软件中心"
