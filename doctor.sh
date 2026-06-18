#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

echo "================ 系统信息 ================"
[ -f /etc/openwrt_release ] && cat /etc/openwrt_release || true
echo
echo "包管理器: $(detect_pkg_mgr)"
if command -v apk >/dev/null 2>&1; then
    echo "APK 架构: $(apk --print-arch 2>/dev/null || true)"
fi
echo
echo "空间:"
df -h
echo
echo "挂载:"
mount | grep -E ' on / | on /overlay ' || true
