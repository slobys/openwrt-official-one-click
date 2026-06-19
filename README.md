# OpenWrt Official One Click

官方原版 OpenWrt 首次安装辅助脚本，面向 25.12+ / `apk` 环境。

## 一键使用

推荐安装一个菜单命令，后续直接输入 `openwrt-easy`：

```sh
curl -kfsSL -o /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

如果系统没有 `curl`，可以试试 `wget`：

```sh
wget -qO /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

国内用户可用 Gitee：

```sh
curl -kfsSL -o /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && RAW_BASE=https://gitee.com/naiyou88/openwrt-official-one-click/raw/main openwrt-easy
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
openwrt-easy --passwall
openwrt-easy --passwall-local
openwrt-easy --passwall-run
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
3. 在线安装 / 更新 PassWall
4. 安装 /tmp/passwall 本地离线 APK 包
5. 安装 /tmp/passwall-run 本地 .run 包
6. 安装 / 更新 iStore 软件中心
7. 安装 Argon 主题
8. 查看系统信息
0. 退出
```

## 这篇教程里适合一键化的部分

- 基础初始化：安装 SFTP、中文语言包、常用下载工具，重启 LuCI 服务。
- overlay 扩容：检测 overlayfs、选择磁盘、创建 ext4 分区、写入 fstab。
- PassWall 安装：识别架构和 25.12 目录，自动下载主程序、中文包和常用运行依赖。
- 离线安装：SourceForge 在软路由上慢时，优先下载对应架构的 `.run` 包，上传到 OpenWrt 后一条命令安装。
- iStore 软件中心：下载官方 `istore-reinstall.run` 安装脚本，只允许 `x86_64` 和 `arm64` 设备执行。
- Argon 主题：下载并安装教程里的主题 APK。

不建议脚本硬做的部分：

- 刷写固件和 Rufus 操作，保留人工确认更稳。
- 首次登录密码、LAN 网段、上级路由位置，这些要按现场网络决定。
- 默认强制重启，脚本只在扩容最后询问。

## PassWall 慢的处理方式

优先方式是在软路由上直接执行：

```sh
openwrt-easy --passwall
```

脚本会：

- 优先从 GitHub Release 获取 PassWall 主程序和中文包。
- 运行依赖从 `openwrt-passwall-build` 的 25.12 APK 目录匹配最新版。
- 下载到临时目录后用 `apk add --allow-untrusted` 一次安装。

如果 SourceForge 在软路由上下载很慢：

1. Windows 电脑运行 `download-passwall-run-windows.bat`，或在 Release 页面下载对应架构的 `.run` 文件。
2. 上传到软路由 `/tmp/passwall-run`，例如 `/tmp/passwall-run/PassWall_26.6.2_x86_64_all_sdk_24.10.run`。
3. SSH 执行：

```sh
mkdir -p /tmp/passwall-run
OPENWRT_EASY_FORCE_UPDATE=1 openwrt-easy --passwall-run
```

也可以直接执行：

```sh
sh /tmp/passwall-run/PassWall_26.6.2_x86_64_all_sdk_24.10.run
```

当前预打包方向：

| 文件名架构 | 上游包目录 | 常见设备 |
|------------|------------|----------|
| `x86_64` | `x86_64` | x86 软路由 |
| `aarch64_generic` | `aarch64_generic` | NanoPi R4S / R5S / R6S 等常见 ARM64 |
| `aarch64_a53` | `aarch64_cortex-a53` | Cortex-A53 ARM64 |
| `aarch64_a72` | `aarch64_cortex-a72` | Cortex-A72 ARM64 |

PassWall 26.6.2 `.run` 下载：

| 架构 | GitHub | Gitee |
|------|--------|-------|
| `x86_64` | [下载](https://github.com/slobys/openwrt-official-one-click/releases/latest/download/PassWall_26.6.2_x86_64_all_sdk_24.10.run) | [下载](https://gitee.com/naiyou88/openwrt-official-one-click/releases/download/passwall-26.6.2/PassWall_26.6.2_x86_64_all_sdk_24.10.run) |
| `aarch64_generic` | [下载](https://github.com/slobys/openwrt-official-one-click/releases/latest/download/PassWall_26.6.2_aarch64_generic_all_sdk_24.10.run) | [下载](https://gitee.com/naiyou88/openwrt-official-one-click/releases/download/passwall-26.6.2/PassWall_26.6.2_aarch64_generic_all_sdk_24.10.run) |
| `aarch64_a53` | [下载](https://github.com/slobys/openwrt-official-one-click/releases/latest/download/PassWall_26.6.2_aarch64_a53_all_sdk_24.10.run) | [下载](https://gitee.com/naiyou88/openwrt-official-one-click/releases/download/passwall-26.6.2/PassWall_26.6.2_aarch64_a53_all_sdk_24.10.run) |
| `aarch64_a72` | [下载](https://github.com/slobys/openwrt-official-one-click/releases/latest/download/PassWall_26.6.2_aarch64_a72_all_sdk_24.10.run) | [下载](https://gitee.com/naiyou88/openwrt-official-one-click/releases/download/passwall-26.6.2/PassWall_26.6.2_aarch64_a72_all_sdk_24.10.run) |

旧的 APK 文件夹方式仍然保留：

1. Windows 电脑运行 `download-passwall-windows.bat`。
2. 按提示输入架构，例如 `aarch64_generic`。
3. 把生成文件夹里的 `.apk` 上传到软路由 `/tmp/passwall`。
4. SSH 执行：

```sh
openwrt-easy --passwall-local
```

也可以不走菜单，直接：

```sh
cd /tmp/passwall
apk add --allow-untrusted ./*.apk
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## 文件说明

| 文件 | 作用 |
|------|------|
| `bootstrap.sh` | 安装并启动 `openwrt-easy` 菜单 |
| `menu.sh` | 菜单入口 |
| `system-init.sh` | 中文界面、SFTP、常用工具 |
| `expand-overlay.sh` | overlay 扩容 |
| `passwall.sh` | PassWall 在线 / 本地 APK 安装 |
| `passwall-run-install.sh` | 执行上传到 `/tmp/passwall-run` 的 `.run` 包 |
| `build-passwall-run.sh` | 生成 PassWall 自解压 `.run` 包 |
| `istore.sh` | 安装 / 更新 iStore 软件中心 |
| `theme-argon.sh` | Argon 主题安装 |
| `doctor.sh` | 查看系统、架构、空间信息 |
| `download-passwall-run-windows.bat` | Windows 电脑端下载 `.run` 离线包 |
| `download-passwall-windows.bat` | Windows 电脑端离线下载 APK |

## 维护者打包

在电脑或服务器上执行：

```sh
sh build-passwall-run.sh --all
```

会生成：

```text
dist/passwall-run/PassWall_<版本>_x86_64_all_sdk_24.10.run
dist/passwall-run/PassWall_<版本>_aarch64_generic_all_sdk_24.10.run
dist/passwall-run/PassWall_<版本>_aarch64_a53_all_sdk_24.10.run
dist/passwall-run/PassWall_<版本>_aarch64_a72_all_sdk_24.10.run
```

单独打一个架构：

```sh
sh build-passwall-run.sh --arch aarch64_generic
```

## 注意

- 当前重点适配 OpenWrt 25.12+ / `apk`。
- overlay 扩容会修改分区表，执行前先备份配置。
- 基础初始化会恢复 BusyBox wget；OpenWrt 25.12 的 apk 在部分机型上会被完整 wget / wget-nossl 影响。
- PassWall 是否有对应架构包取决于上游构建。
- `.run` 包内置 PassWall 上游 APK，但系统基础依赖仍可能需要 OpenWrt 官方源可访问。
- Gitee 可能对 PassWall 相关脚本返回 451；菜单仍可正常打开，PassWall 功能需要 GitHub raw 可访问或使用离线 `.run` 包。
- iStore 官方安装脚本只支持 `x86_64` 和 `arm64` 设备，其它架构会直接退出。
- 脚本不会自动修改 PassWall 配置。

## 致谢

- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall build: <https://sourceforge.net/projects/openwrt-passwall-build/>
- iStore: <https://github.com/linkease/istore>
- Argon: <https://github.com/jerrykuku/luci-theme-argon>
