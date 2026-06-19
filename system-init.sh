#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

install_pkg() {
    pkg="$1"
    log "安装: $pkg"
    if pkg_install_one "$pkg"; then
        return 0
    fi

    if [ "$(detect_pkg_mgr)" = "apk" ]; then
        warn "安装失败，清理 apk 缓存后重试: $pkg"
        rm -f /var/cache/apk/* /tmp/*.apk 2>/dev/null || true
        pkg_update || true
        pkg_install_one "$pkg" && return 0
    fi

    warn "安装失败或软件源不存在: $pkg"
    return 1
}

log "更新软件源"
pkg_update || warn "软件源更新失败，继续尝试安装常用包"

install_pkg ca-bundle || true
install_pkg curl || true

if [ "$(detect_pkg_mgr)" = "apk" ]; then
    if apk info -e wget-nossl >/dev/null 2>&1; then
        warn "检测到 wget-nossl，移除后改装 wget-ssl，避免 HTTPS 软件包下载中断"
        apk del wget-nossl || true
    fi
    install_pkg wget-ssl || true
else
    install_pkg wget-ssl || install_pkg wget || true
fi

for pkg in openssh-sftp-server luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn; do
    install_pkg "$pkg" || true
done

[ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear restart >/dev/null 2>&1 || true
refresh_luci

log "基础初始化完成"
