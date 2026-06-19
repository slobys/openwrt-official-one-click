#!/bin/sh
set -eu

PROJECT_NAME="openwrt-official-one-click"
REPO="${REPO:-slobys/openwrt-official-one-click}"
BRANCH="${BRANCH:-main}"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/$REPO/$BRANCH}"
CACHE_DIR="/usr/lib/$PROJECT_NAME"
BIN_NAME="${BIN_NAME:-openwrt-easy}"

log() {
    printf '%s\n' "==> $*"
}

die() {
    printf '%s\n' "[ERROR] $*" >&2
    exit 1
}

download_file() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$output" && return 0
        curl -kfsSL --retry 2 --connect-timeout 20 "$url" -o "$output" && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url" && return 0
        wget --no-check-certificate -qO "$output" "$url" && return 0
    fi

    return 1
}

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/menu.sh" ] && [ -f "$SCRIPT_DIR/common.sh" ]; then
    exec sh "$SCRIPT_DIR/menu.sh" "$@"
fi

[ "$(id -u)" = "0" ] || die "请使用 root 用户执行"
mkdir -p "$CACHE_DIR"

for file in common.sh menu.sh system-init.sh expand-overlay.sh passwall.sh passwall-run-install.sh istore.sh theme-argon.sh doctor.sh; do
    target="$CACHE_DIR/$file"
    if [ ! -s "$target" ] || [ "${OPENWRT_EASY_FORCE_UPDATE:-0}" = "1" ]; then
        log "下载: $file"
        download_file "$RAW_BASE/$file" "$target" || die "下载失败: $RAW_BASE/$file"
        chmod +x "$target"
    fi
done

if [ ! -f "/usr/bin/$BIN_NAME" ]; then
    cp "$0" "/usr/bin/$BIN_NAME" 2>/dev/null && chmod +x "/usr/bin/$BIN_NAME" || true
fi

exec sh "$CACHE_DIR/menu.sh" "$@"
