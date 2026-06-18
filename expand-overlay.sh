#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/common.sh"

need_root

echo "================================================"
echo " OpenWrt overlay 通用自定义扩容脚本"
echo " 支持输入: 2G / 4G / 8G / 4096M / all"
echo "================================================"
echo

echo "[1/11] 当前空间情况:"
df -h
echo

echo "[2/11] 检查当前系统是否为 overlayfs 模式"
if ! mount | grep -q "overlayfs:/overlay on /"; then
    echo "当前系统看起来不是 overlayfs 根目录。"
    echo "如果刷的是 x86 EXT4 版本，一般应该扩根分区，不适合使用本脚本。"
    mount | grep " on / " || true
    exit 1
fi

OVERLAY_SRC="$(df /overlay | awk 'NR==2{print $1}')"
echo "当前 /overlay 来源: $OVERLAY_SRC"
case "$OVERLAY_SRC" in
    /dev/mmcblk*|/dev/sd*|/dev/nvme*|/dev/vd*|/dev/xvd*)
        echo "检测到 /overlay 已经是独立磁盘分区，可能已经扩容过。"
        exit 0
        ;;
esac
echo

echo "[3/11] 安装扩容所需工具"
pkg_update || warn "软件源更新失败，继续尝试安装工具"
for pkg in block-mount e2fsprogs kmod-fs-ext4 parted; do
    pkg_install_one "$pkg" || die "安装失败: $pkg"
done

echo
echo "[4/11] 检测磁盘设备"
CHOICE_FILE="/tmp/expand_overlay_disks.$$"
: > "$CHOICE_FILE"
IDX=1
for d in /dev/mmcblk[0-9] /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z] /dev/xvd[a-z]; do
    [ -b "$d" ] || continue
    if parted -s "$d" unit MiB print >/dev/null 2>&1; then
        DISK_SIZE="$(parted -m "$d" unit MiB print 2>/dev/null | awk -F: 'NR==2{gsub("MiB","",$2); print int($2)}')"
        LAST_END="$(parted -m "$d" unit MiB print 2>/dev/null | awk -F: '/^[0-9]+:/{gsub("MiB","",$3); last=$3} END{print int(last+1)}')"
        [ -n "$DISK_SIZE" ] || continue
        [ -n "$LAST_END" ] || continue
        FREE_MB=$((DISK_SIZE - LAST_END))
        MODEL="$(cat "/sys/block/$(basename "$d")/device/model" 2>/dev/null || true)"
        [ -n "$MODEL" ] || MODEL="-"
        echo "$IDX $d $DISK_SIZE $FREE_MB" >> "$CHOICE_FILE"
        echo "[$IDX] 磁盘: $d"
        echo "    型号: $MODEL"
        echo "    总容量约: ${DISK_SIZE} MiB"
        echo "    末尾可用空间约: ${FREE_MB} MiB"
        echo
        IDX=$((IDX + 1))
    fi
done

COUNT="$(wc -l < "$CHOICE_FILE" | tr -d ' ')"
if [ "$COUNT" -eq 0 ]; then
    rm -f "$CHOICE_FILE"
    die "没有检测到可用磁盘"
fi

if [ "$COUNT" -eq 1 ]; then
    DISK="$(awk 'NR==1{print $2}' "$CHOICE_FILE")"
    echo "只检测到一个磁盘，自动选择: $DISK"
else
    echo "检测到多个磁盘，请确认 OpenWrt 安装在哪个磁盘上。"
    printf "请输入要扩容的磁盘编号: "
    read SELECT_ID
    DISK="$(awk -v id="$SELECT_ID" '$1==id{print $2}' "$CHOICE_FILE")"
    [ -n "$DISK" ] || die "选择无效"
fi
rm -f "$CHOICE_FILE"
echo

echo "[5/11] 显示当前分区表"
parted -s "$DISK" unit MiB print free
echo

DISK_SIZE="$(parted -m "$DISK" unit MiB print | awk -F: 'NR==2{gsub("MiB","",$2); print int($2)}')"
LAST_END="$(parted -m "$DISK" unit MiB print | awk -F: '/^[0-9]+:/{gsub("MiB","",$3); last=$3} END{print int(last+1)}')"
LAST_NUM="$(parted -m "$DISK" unit MiB print | awk -F: '/^[0-9]+:/{last=$1} END{print int(last)}')"
[ -n "$DISK_SIZE" ] || die "无法读取磁盘容量"
[ -n "$LAST_END" ] || die "无法读取最后分区结束位置"
[ -n "$LAST_NUM" ] || die "无法读取最后分区编号"

FREE_MB=$((DISK_SIZE - LAST_END))
RESERVE_MB=16
MAX_MB=$((FREE_MB - RESERVE_MB))
echo "磁盘总容量约: ${DISK_SIZE} MiB"
echo "末尾可用于新建 overlay 分区的空间约: ${FREE_MB} MiB"
[ "$MAX_MB" -ge 512 ] || die "剩余空间不足 512MB，不建议继续"
echo

echo "[6/11] 请选择新的 overlay 分区大小"
echo "示例: 2G / 4G / 8G / 4096M / all"
printf "请输入 overlay 大小 [默认 4G]: "
read SIZE_INPUT
[ -n "$SIZE_INPUT" ] || SIZE_INPUT="4G"
SIZE_INPUT_LOWER="$(echo "$SIZE_INPUT" | tr 'A-Z' 'a-z')"
case "$SIZE_INPUT_LOWER" in
    all)
        SIZE_MB="$MAX_MB"
        ;;
    *g)
        NUM="$(echo "$SIZE_INPUT_LOWER" | sed 's/g$//')"
        echo "$NUM" | grep -qE '^[0-9]+$' || die "大小格式不正确，例如 4G"
        SIZE_MB=$((NUM * 1024))
        ;;
    *m)
        NUM="$(echo "$SIZE_INPUT_LOWER" | sed 's/m$//')"
        echo "$NUM" | grep -qE '^[0-9]+$' || die "大小格式不正确，例如 4096M"
        SIZE_MB="$NUM"
        ;;
    *)
        echo "$SIZE_INPUT_LOWER" | grep -qE '^[0-9]+$' || die "大小格式不正确，请输入 4G、4096M 或 all"
        SIZE_MB="$SIZE_INPUT_LOWER"
        ;;
esac

[ "$SIZE_MB" -ge 512 ] || die "overlay 小于 512MB，太小了"
[ "$SIZE_MB" -le "$MAX_MB" ] || die "你输入的大小超过磁盘剩余空间，最多可用 ${MAX_MB} MiB"

START_MB="$LAST_END"
END_MB=$((START_MB + SIZE_MB))
echo
echo "准备创建新的 overlay 分区:"
echo "  磁盘设备: $DISK"
echo "  开始位置: ${START_MB} MiB"
echo "  结束位置: ${END_MB} MiB"
echo "  分区大小: ${SIZE_MB} MiB"
echo
echo "警告: 接下来会修改磁盘分区表。建议已经备份配置。"
printf "确认继续请输入 yes: "
read CONFIRM
CONFIRM="$(echo "$CONFIRM" | tr 'a-z' 'A-Z')"
[ "$CONFIRM" = "YES" ] || die "已取消"

echo
echo "[7/11] 新建 overlay 分区"
parted -s "$DISK" unit MiB mkpart primary ext4 "${START_MB}MiB" "${END_MB}MiB"
sleep 3
command -v partprobe >/dev/null 2>&1 && partprobe "$DISK" 2>/dev/null || true
sleep 3
block info >/dev/null 2>&1 || true
sleep 2

NEW_NUM="$(parted -m "$DISK" unit MiB print | awk -F: '/^[0-9]+:/{last=$1} END{print int(last)}')"
case "$DISK" in
    /dev/mmcblk*|/dev/nvme*) NEW_PART="${DISK}p${NEW_NUM}" ;;
    *) NEW_PART="${DISK}${NEW_NUM}" ;;
esac

if [ ! -b "$NEW_PART" ]; then
    echo "新分区已经写入分区表，但系统暂时没有识别到设备: $NEW_PART"
    echo "请先重启一次，确认能看到 $NEW_PART 后再继续。"
    exit 1
fi

echo "新建分区: $NEW_PART"
echo
echo "[8/11] 格式化新分区为 ext4"
mkfs.ext4 -F -L openwrt_overlay "$NEW_PART"

echo
echo "[9/11] 复制当前 overlay 数据到新分区"
mkdir -p /mnt/new_overlay
mount "$NEW_PART" /mnt/new_overlay
tar -C /overlay -cpf - . | tar -C /mnt/new_overlay -xpf -
sync
umount /mnt/new_overlay

echo
echo "[10/11] 写入 OpenWrt 挂载配置"
UUID="$(block info "$NEW_PART" | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')"
[ -n "$UUID" ] || die "无法获取新分区 UUID"
uci -q delete fstab.universal_overlay || true
uci set fstab.universal_overlay='mount'
uci set fstab.universal_overlay.target='/overlay'
uci set fstab.universal_overlay.uuid="$UUID"
uci set fstab.universal_overlay.fstype='ext4'
uci set fstab.universal_overlay.enabled='1'
uci set fstab.universal_overlay.enabled_fsck='1'
uci commit fstab
/etc/init.d/fstab enable 2>/dev/null || true

echo
echo "[11/11] 配置完成"
echo "新的 overlay 分区: $NEW_PART"
echo "overlay 大小: ${SIZE_MB} MiB"
echo "UUID: $UUID"
echo
printf "是否现在重启？输入 yes 立即重启: "
read REBOOT_NOW
REBOOT_NOW="$(echo "$REBOOT_NOW" | tr 'a-z' 'A-Z')"
if [ "$REBOOT_NOW" = "YES" ]; then
    reboot
else
    echo "你可以稍后手动执行: reboot"
fi
