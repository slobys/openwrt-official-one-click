# OpenWrt Official One Click

官方原版 OpenWrt 首次安装辅助脚本，面向 25.12+ / `apk` 环境。

## 一键使用

国内用户推荐用 Gitee + `wget` 安装菜单命令，后续直接输入 `openwrt-easy`：

```sh
wget -qO /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && RAW_BASE=https://gitee.com/naiyou88/openwrt-official-one-click/raw/main openwrt-easy
```

如果系统已经有 `curl`，也可以用 Gitee：

```sh
curl -kfsSL -o /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && RAW_BASE=https://gitee.com/naiyou88/openwrt-official-one-click/raw/main openwrt-easy
```

GitHub 源：

```sh
wget -qO /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

GitHub `curl` 源：

```sh
curl -kfsSL -o /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

完整项目方式：

```sh
git clone https://github.com/slobys/openwrt-official-one-click.git
cd openwrt-official-one-click
sh menu.sh
```

常用命令：

```sh
openwrt-easy --init
openwrt-easy --expand-overlay
openwrt-easy --istore
openwrt-easy --argon
openwrt-easy --doctor
```

如果之前已经安装过旧版菜单，先强制刷新一次：

```sh
OPENWRT_EASY_FORCE_UPDATE=1 openwrt-easy
```

国内网络刷新可直接走 Gitee：

```sh
OPENWRT_EASY_FORCE_UPDATE=1 RAW_BASE=https://gitee.com/naiyou88/openwrt-official-one-click/raw/main openwrt-easy
```

## 菜单功能

```text
1. 基础初始化（中文界面 / SFTP / 常用下载工具）
2. 自定义 overlay 扩容
3. 安装 / 更新 iStore 软件中心
4. 安装 Argon 主题
5. 查看系统信息
0. 退出
```

## 这篇教程里适合一键化的部分

- 基础初始化：安装 SFTP、中文语言包、常用下载工具，重启 LuCI 服务。
- overlay 扩容：检测 overlayfs、选择磁盘、创建 ext4 分区、写入 fstab。
- iStore 软件中心：优先使用 iStore 仓库直装，失败时改用官方 `istore-reinstall.run`，只允许 `x86_64` 和 `arm64` 设备执行。
- Argon 主题：下载并安装教程里的主题 APK。

不建议脚本硬做的部分：

- 刷写固件和 Rufus 操作，保留人工确认更稳。
- 首次登录密码、LAN 网段、上级路由位置，这些要按现场网络决定。
- 默认强制重启，脚本只在扩容最后询问。

## 文件说明

| 文件 | 作用 |
|------|------|
| `bootstrap.sh` | 安装并启动 `openwrt-easy` 菜单 |
| `menu.sh` | 菜单入口 |
| `system-init.sh` | 中文界面、SFTP、常用工具 |
| `expand-overlay.sh` | overlay 扩容 |
| `istore.sh` | 安装 / 更新 iStore 软件中心 |
| `theme-argon.sh` | Argon 主题安装 |
| `doctor.sh` | 查看系统、架构、空间信息 |

## 注意

- 当前重点适配 OpenWrt 25.12+ / `apk`。
- overlay 扩容会修改分区表，执行前先备份配置。
- 基础初始化会恢复 OpenWrt 默认的 `uclient-fetch` wget；OpenWrt 25.12 的 apk 在部分机型上会被完整 wget / wget-nossl 影响。
- iStore 安装会先补 `curl` / `ca-bundle`，再从 `istore.linkease.com` / `istore.istoreos.com` / `repo.istoreos.com` 仓库直装，避开 GitHub 官方脚本超时。
- iStore 官方安装脚本只支持 `x86_64` 和 `arm64` 设备，其它架构会直接退出。

## 致谢

- iStore: <https://github.com/linkease/istore>
- Argon: <https://github.com/jerrykuku/luci-theme-argon>
