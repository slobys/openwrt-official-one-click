#!/bin/sh
set -eu

PROJECT_NAME="openwrt-official-one-click"
REPO="${REPO:-slobys/openwrt-official-one-click}"
BRANCH="${BRANCH:-main}"
GITHUB_RAW_BASE="${GITHUB_RAW_BASE:-https://raw.githubusercontent.com/$REPO/$BRANCH}"
RAW_BASE="${RAW_BASE:-$GITHUB_RAW_BASE}"
GITEE_RAW_BASE="${GITEE_RAW_BASE:-https://gitee.com/naiyou88/openwrt-official-one-click/raw/$BRANCH}"
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
    tmp="$output.tmp.$$"
    rm -f "$tmp"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$tmp"; then
            mv "$tmp" "$output"
            return 0
        fi
        if curl -kfsSL --retry 2 --connect-timeout 20 "$url" -o "$tmp"; then
            mv "$tmp" "$output"
            return 0
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -qO "$tmp" "$url"; then
            mv "$tmp" "$output"
            return 0
        fi
        if wget --help 2>&1 | grep -q -- '--no-check-certificate'; then
            if wget --no-check-certificate -qO "$tmp" "$url"; then
                mv "$tmp" "$output"
                return 0
            fi
        fi
    fi

    rm -f "$tmp"
    return 1
}

download_script() {
    file="$1"
    output="$2"
    tried=""

    for base in "$RAW_BASE" "$GITEE_RAW_BASE" "$GITHUB_RAW_BASE"; do
        [ -n "$base" ] || continue
        case " $tried " in
            *" $base "*) continue ;;
        esac
        tried="$tried $base"
        download_file "$base/$file" "$output" && return 0
        log "下载源失败，尝试下一个: $file"
    done

    return 1
}

required_script() {
    case "$1" in
        common.sh|menu.sh|system-init.sh|expand-overlay.sh|istore.sh|theme-argon.sh|doctor.sh) return 0 ;;
        *) return 1 ;;
    esac
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
        if ! download_script "$file" "$target"; then
            if required_script "$file"; then
                die "下载失败: $file"
            fi
            log "跳过可选脚本: $file"
            rm -f "$target"
            continue
        fi
        chmod +x "$target"
    fi
done

if [ ! -f "/usr/bin/$BIN_NAME" ]; then
    cp "$0" "/usr/bin/$BIN_NAME" 2>/dev/null && chmod +x "/usr/bin/$BIN_NAME" || true
fi

exec sh "$CACHE_DIR/menu.sh" "$@"
