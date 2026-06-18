#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

log "更新软件源"
pkg_update || warn "软件源更新失败，继续尝试安装常用包"

for pkg in ca-bundle curl wget openssh-sftp-server luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn; do
    log "安装: $pkg"
    pkg_install_one "$pkg" || warn "安装失败或软件源不存在: $pkg"
done

[ -x /etc/init.d/dropbear ] && /etc/init.d/dropbear restart >/dev/null 2>&1 || true
refresh_luci

log "基础初始化完成"
