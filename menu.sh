#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

usage() {
    cat <<'EOF'
用法:
  sh menu.sh
  sh menu.sh --init
  sh menu.sh --expand-overlay
  sh menu.sh --passwall
  sh menu.sh --passwall-local
  sh menu.sh --argon
  sh menu.sh --doctor
EOF
}

run_action() {
    action="$1"
    case "$action" in
        --init) run_script system-init.sh ;;
        --expand-overlay) run_script expand-overlay.sh ;;
        --passwall) run_script passwall.sh ;;
        --passwall-local) run_script passwall.sh --local ;;
        --argon) run_script theme-argon.sh ;;
        --doctor) run_script doctor.sh ;;
        --help|-h) usage ;;
        *) die "未知参数: $action" ;;
    esac
}

if [ "$#" -gt 0 ]; then
    run_action "$1"
    exit 0
fi

while :; do
    cat <<'EOF'

================ OpenWrt 官方原版一键助手 ================
1. 基础初始化（中文界面 / SFTP / 常用下载工具）
2. 自定义 overlay 扩容
3. 在线安装 / 更新 PassWall
4. 安装 /tmp/passwall 本地离线 APK 包
5. 安装 Argon 主题
6. 查看系统信息
0. 退出
===========================================================
EOF
    printf "请输入选项 [0-6]: "
    read choice
    case "$choice" in
        1) run_script system-init.sh ;;
        2) run_script expand-overlay.sh ;;
        3) run_script passwall.sh ;;
        4) run_script passwall.sh --local ;;
        5) run_script theme-argon.sh ;;
        6) run_script doctor.sh ;;
        0) exit 0 ;;
        *) warn "无效选项" ;;
    esac
    printf "\n按回车键返回菜单..."
    read _
done
