#!/bin/sh
set -eu

SF_PROJECT="openwrt-passwall-build"
SF_BASE="https://sourceforge.net/projects/$SF_PROJECT/files"
OPENWRT_RELEASE="${OPENWRT_RELEASE:-25.12}"
SDK_TAG="${SDK_TAG:-24.10}"
OUT_DIR="${OUT_DIR:-dist/passwall-run}"
WORK_ROOT="${WORK_ROOT:-/tmp/passwall-run-build.$$}"
DEFAULT_ARCHES="x86_64 aarch64_generic aarch64_a53 aarch64_a72"

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

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

usage() {
    cat <<EOF
用法:
  sh build-passwall-run.sh --all
  sh build-passwall-run.sh --arch x86_64
  sh build-passwall-run.sh --arch aarch64_generic
  sh build-passwall-run.sh --arch aarch64_a53
  sh build-passwall-run.sh --arch aarch64_a72

环境变量:
  OPENWRT_RELEASE=25.12
  SDK_TAG=24.10
  OUT_DIR=dist/passwall-run
EOF
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

valid_pkg_file() {
    file="$1"
    [ -s "$file" ] || return 1
    [ "$(wc -c < "$file")" -gt 1024 ] || return 1
    if head -c 512 "$file" 2>/dev/null | tr 'A-Z' 'a-z' | grep -qE '<html|<!doctype|sourceforge'; then
        return 1
    fi
    return 0
}

source_arch_for() {
    case "$1" in
        x86_64) printf '%s\n' "x86_64" ;;
        aarch64_generic) printf '%s\n' "aarch64_generic" ;;
        aarch64_a53) printf '%s\n' "aarch64_cortex-a53" ;;
        aarch64_a72) printf '%s\n' "aarch64_cortex-a72" ;;
        *) die "不支持的架构: $1" ;;
    esac
}

arch_aliases_for() {
    case "$1" in
        x86_64) printf '%s\n' "x86_64" ;;
        aarch64_generic) printf '%s\n' "aarch64_generic" ;;
        aarch64_a53) printf '%s\n' "aarch64_a53 aarch64_cortex-a53" ;;
        aarch64_a72) printf '%s\n' "aarch64_a72 aarch64_cortex-a72" ;;
        *) die "不支持的架构: $1" ;;
    esac
}

latest_sf_file() {
    source_arch="$1"
    repo="$2"
    regex="$3"
    tmp="$WORK_ROOT/sf-$source_arch-$repo.txt"
    package_dir="releases/packages-$OPENWRT_RELEASE/$source_arch"
    rss_url="https://sourceforge.net/projects/$SF_PROJECT/rss?path=/$package_dir/$repo"
    folder_url="$SF_BASE/$package_dir/$repo/"

    if download_file "$rss_url" "$tmp"; then
        name="$(grep -oE '[A-Za-z0-9._+-]+\.apk' "$tmp" | grep -E "$regex" | head -n1 || true)"
        if [ -n "$name" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi

    if download_file "$folder_url" "$tmp"; then
        name="$(grep -oE '[A-Za-z0-9._+-]+\.apk' "$tmp" | grep -E "$regex" | head -n1 || true)"
        if [ -n "$name" ]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi

    return 1
}

download_sf_package() {
    source_arch="$1"
    repo="$2"
    filename="$3"
    outdir="$4"
    package_dir="releases/packages-$OPENWRT_RELEASE/$source_arch"
    output="$outdir/$filename"

    for url in \
        "https://master.dl.sourceforge.net/project/$SF_PROJECT/$package_dir/$repo/$filename" \
        "https://downloads.sourceforge.net/project/$SF_PROJECT/$package_dir/$repo/$filename" \
        "https://sourceforge.net/projects/$SF_PROJECT/files/$package_dir/$repo/$filename/download"
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
    source_arch="$2"
    repo="$3"
    regex="$4"
    outdir="$5"

    log "匹配: $title"
    filename="$(latest_sf_file "$source_arch" "$repo" "$regex" || true)"
    [ -n "$filename" ] || die "没有找到 $title: $source_arch / $OPENWRT_RELEASE"
    log "下载: $filename"
    download_sf_package "$source_arch" "$repo" "$filename" "$outdir" || die "下载失败: $filename"
    printf '%s\n' "$filename" >> "$outdir/../manifest.txt"
}

write_runner() {
    runner="$1"
    label_arch="$2"
    source_arch="$3"
    aliases="$4"
    passwall_version="$5"

    cat > "$runner" <<EOF
#!/bin/sh
set -eu

PACKAGE_NAME="$(basename "$runner")"
PASSWALL_VERSION="$passwall_version"
OPENWRT_RELEASE="$OPENWRT_RELEASE"
PACKAGE_ARCH="$label_arch"
SOURCE_ARCH="$source_arch"
ARCH_ALIASES="$aliases"

log() {
    printf '%s\n' "==> \$*"
}

warn() {
    printf '%s\n' "[WARN] \$*" >&2
}

die() {
    printf '%s\n' "[ERROR] \$*" >&2
    exit 1
}

need_cmd() {
    command -v "\$1" >/dev/null 2>&1 || die "缺少命令: \$1"
}

runtime_arch() {
    arch=""
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release
        arch="\${DISTRIB_ARCH:-}"
    fi
    [ -n "\$arch" ] || arch="\$(apk --print-arch 2>/dev/null || true)"
    [ -n "\$arch" ] || die "无法识别当前 OpenWrt 架构"
    printf '%s\n' "\$arch"
}

arch_allowed() {
    current="\$1"
    for item in \$ARCH_ALIASES; do
        [ "\$current" = "\$item" ] && return 0
    done
    return 1
}

refresh_luci() {
    rm -rf /tmp/luci-* /tmp/.luci* /var/run/luci-indexcache 2>/dev/null || true
    [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}

[ "\$(id -u)" = "0" ] || die "请使用 root 用户执行"
need_cmd apk
need_cmd awk
need_cmd tail
need_cmd gzip
need_cmd tar

current_arch="\$(runtime_arch)"
if ! arch_allowed "\$current_arch"; then
    die "架构不匹配：当前 \$current_arch，安装包适用于 \$ARCH_ALIASES"
fi

tmp_dir="/tmp/passwall-run.\$\$"
cleanup() {
    rm -rf "\$tmp_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
mkdir -p "\$tmp_dir"

payload_line="\$(awk '/^__PASSWALL_RUN_PAYLOAD_BELOW__\$/ { print NR + 1; exit 0; }' "\$0")"
[ -n "\$payload_line" ] || die "安装包损坏：找不到 payload"

log "解包 \$PACKAGE_NAME"
tail -n +"\$payload_line" "\$0" | gzip -dc | tar -xf - -C "\$tmp_dir"

set -- "\$tmp_dir"/apks/*.apk
[ -e "\$1" ] || die "安装包损坏：没有找到 APK"

log "安装 PassWall \$PASSWALL_VERSION"
apk add --allow-untrusted "\$@"
refresh_luci

installed="\$(apk info -a luci-app-passwall 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
log "安装后版本: \${installed:-unknown}"
log "PassWall .run 安装完成"
exit 0

__PASSWALL_RUN_PAYLOAD_BELOW__
EOF
}

build_one() {
    label_arch="$1"
    source_arch="$(source_arch_for "$label_arch")"
    aliases="$(arch_aliases_for "$label_arch")"
    work_dir="$WORK_ROOT/$label_arch"
    apk_dir="$work_dir/apks"
    manifest="$work_dir/manifest.txt"

    rm -rf "$work_dir"
    mkdir -p "$apk_dir"
    : > "$manifest"

    log "开始打包: $label_arch ($source_arch)"
    download_target "luci-app-passwall" "$source_arch" "passwall_luci" '^luci-app-passwall-[0-9].*\.apk$' "$apk_dir"
    download_target "luci-i18n-passwall-zh-cn" "$source_arch" "passwall_luci" '^luci-i18n-passwall-zh-cn-[0-9].*\.apk$' "$apk_dir"
    download_target "chinadns-ng" "$source_arch" "passwall_packages" '^chinadns-ng-[0-9].*\.apk$' "$apk_dir"
    download_target "dns2socks" "$source_arch" "passwall_packages" '^dns2socks-[0-9].*\.apk$' "$apk_dir"
    download_target "tcping" "$source_arch" "passwall_packages" '^tcping-[0-9].*\.apk$' "$apk_dir"
    download_target "geoview" "$source_arch" "passwall_packages" '^geoview-[0-9].*\.apk$' "$apk_dir"
    download_target "xray-core" "$source_arch" "passwall_packages" '^xray-core-[0-9].*\.apk$' "$apk_dir"
    download_target "sing-box" "$source_arch" "passwall_packages" '^sing-box-[0-9].*\.apk$' "$apk_dir"
    download_target "hysteria" "$source_arch" "passwall_packages" '^hysteria-[0-9].*\.apk$' "$apk_dir"
    download_target "v2ray-geoip" "$source_arch" "passwall_packages" '^v2ray-geoip-[0-9].*\.apk$' "$apk_dir"
    download_target "v2ray-geosite" "$source_arch" "passwall_packages" '^v2ray-geosite-[0-9].*\.apk$' "$apk_dir"

    passwall_apk="$(ls "$apk_dir"/luci-app-passwall-*.apk | head -n1)"
    passwall_version="$(basename "$passwall_apk" | sed -n 's/^luci-app-passwall-\([0-9][0-9.]*\).*/\1/p')"
    [ -n "$passwall_version" ] || passwall_version="unknown"

    package_name="PassWall_${passwall_version}_${label_arch}_all_sdk_${SDK_TAG}.run"
    output="$OUT_DIR/$package_name"
    payload="$work_dir/payload.tar.gz"

    {
        printf 'name=%s\n' "$package_name"
        printf 'passwall_version=%s\n' "$passwall_version"
        printf 'openwrt_release=%s\n' "$OPENWRT_RELEASE"
        printf 'sdk_tag=%s\n' "$SDK_TAG"
        printf 'package_arch=%s\n' "$label_arch"
        printf 'source_arch=%s\n' "$source_arch"
        printf 'arch_aliases=%s\n' "$aliases"
        printf 'created_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf '\nfiles:\n'
        sed 's/^/- /' "$manifest"
    } > "$work_dir/README.txt"

    (cd "$work_dir" && tar -czf "$payload" apks README.txt manifest.txt)
    mkdir -p "$OUT_DIR"
    write_runner "$output" "$label_arch" "$source_arch" "$aliases" "$passwall_version"
    cat "$payload" >> "$output"
    chmod +x "$output"
    log "已生成: $output"
}

main() {
    need_cmd grep
    need_cmd sed
    need_cmd awk
    need_cmd basename
    need_cmd tar
    need_cmd gzip
    need_cmd ls
    mkdir -p "$WORK_ROOT"
    trap 'rm -rf "$WORK_ROOT" 2>/dev/null || true' EXIT INT TERM

    arches=""
    if [ "$#" -eq 0 ]; then
        usage
        exit 0
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all)
                arches="$DEFAULT_ARCHES"
                shift
                ;;
            --arch)
                [ "$#" -ge 2 ] || die "--arch 需要参数"
                arches="$arches $2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                die "未知参数: $1"
                ;;
        esac
    done

    [ -n "$arches" ] || die "请指定 --all 或 --arch"
    for arch in $arches; do
        build_one "$arch"
    done
}

main "$@"
