#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

RUN_DIR="${RUN_DIR:-/tmp/passwall-run}"

need_root

run_file="${1:-}"
if [ -z "$run_file" ]; then
    set -- "$RUN_DIR"/PassWall_*.run /tmp/PassWall_*.run
    [ -e "$1" ] || die "没有找到 .run 包，请上传到 $RUN_DIR 或 /tmp"
    run_file="$1"
fi

[ -f "$run_file" ] || die "文件不存在: $run_file"

log "执行 PassWall .run 安装包: $run_file"
sh "$run_file"
install_passwall_nft_kmods
refresh_luci
log "PassWall nftables 透明代理依赖检查完成"
