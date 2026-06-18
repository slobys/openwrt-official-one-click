# OpenWrt Official One Click

官方原版 OpenWrt 首次安装辅助脚本，面向 25.12+ / `apk` 环境。

## 一键使用

推荐安装一个菜单命令，后续直接输入 `openwrt-easy`：

```sh
wget --no-check-certificate -qO /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

如果系统已经有 `curl`，也可以用：

```sh
curl -fsSL -o /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
```

国内用户可用 Gitee：

```sh
wget --no-check-certificate -qO /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy
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
openwrt-easy --argon
openwrt-easy --doctor
```

## 菜单功能

```text
1. 基础初始化（中文界面 / SFTP / 常用下载工具）
2. 自定义 overlay 扩容
3. 在线安装 / 更新 PassWall
4. 安装 /tmp/passwall 本地离线 APK 包
5. 安装 Argon 主题
6. 查看系统信息
0. 退出
```

## 这篇教程里适合一键化的部分

- 基础初始化：安装 SFTP、中文语言包、常用下载工具，重启 LuCI 服务。
- overlay 扩容：检测 overlayfs、选择磁盘、创建 ext4 分区、写入 fstab。
- PassWall 安装：识别架构和 25.12 目录，自动下载主程序、中文包和常用运行依赖。
- 离线安装：SourceForge 在软路由上慢时，先用 Windows 工具把 APK 下载到电脑，再上传到 `/tmp/passwall` 安装。
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
| `theme-argon.sh` | Argon 主题安装 |
| `doctor.sh` | 查看系统、架构、空间信息 |
| `download-passwall-windows.bat` | Windows 电脑端离线下载 APK |

## 注意

- 当前重点适配 OpenWrt 25.12+ / `apk`。
- overlay 扩容会修改分区表，执行前先备份配置。
- PassWall 是否有对应架构包取决于上游构建。
- 脚本不会自动修改 PassWall 配置。

## 致谢

- PassWall: <https://github.com/Openwrt-Passwall/openwrt-passwall>
- PassWall build: <https://sourceforge.net/projects/openwrt-passwall-build/>
- Argon: <https://github.com/jerrykuku/luci-theme-argon>
