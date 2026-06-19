#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

restore_busybox_wget() {
    [ "$(detect_pkg_mgr)" = "apk" ] || return 0

    if [ -x /bin/busybox ]; then
        warn "恢复 BusyBox wget，避免完整 wget 破坏 apk 下载"
        ln -sf /bin/busybox /usr/bin/wget
    fi

    apk del wget wget-nossl wget-ssl >/dev/null 2>&1 || true
    [ -x /bin/busybox ] && ln -sf /bin/busybox /usr/bin/wget

    # Failed apk add attempts can leave missing packages in world and block every
    # later apk operation. Remove only missing helper packages managed here.
    for pkg in openssh-sftp-server luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn; do
        apk info -e "$pkg" >/dev/null 2>&1 || apk del "$pkg" >/dev/null 2>&1 || true
    done
}

install_pkg() {
    pkg="$1"
    had_pkg=0
    if [ "$(detect_pkg_mgr)" = "apk" ] && apk info -e "$pkg" >/dev/null 2>&1; then
        had_pkg=1
    fi

    log "安装: $pkg"
    if pkg_install_one "$pkg"; then
        return 0
    fi

    if [ "$(detect_pkg_mgr)" = "apk" ]; then
        warn "安装失败，清理 apk 缓存后重试: $pkg"
        rm -f /var/cache/apk/* /tmp/*.apk 2>/dev/null || true
        pkg_update || true
        pkg_install_one "$pkg" && return 0
        [ "$had_pkg" = "1" ] || apk del "$pkg" >/dev/null 2>&1 || true
    fi

    warn "安装失败或软件源不存在: $pkg"
    return 1
}

restore_busybox_wget

log "更新软件源"
pkg_update || warn "软件源更新失败，继续尝试安装常用包"

install_pkg ca-bundle || true
install_pkg curl || true

for pkg in openssh-sftp-server luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn; do
    install_pkg "$pkg" || true
done

[ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear restart >/dev/null 2>&1 || true
refresh_luci

log "基础初始化完成"
