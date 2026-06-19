# Changelog

## 0.3.5

- iStore 安装增加多 URL 尝试，GitHub 官方 `.run` 下载失败时自动回退。
- 增加 iStore 仓库直装 fallback，从 `luci-app-store` 中提取 `is-opkg` 后安装核心包。
- 通用下载函数不再无条件调用不兼容的 `wget --no-check-certificate`。

## 0.3.4

- 修正 wget 恢复逻辑：OpenWrt 默认应恢复到 `uclient-fetch`，不是 BusyBox。
- 只有 BusyBox 确认带 wget applet 时才回退使用 BusyBox，避免 `wgetwget: applet not found`。

## 0.3.3

- 基础初始化改为先恢复 BusyBox wget，再执行 `apk update`。
- 不再安装 `wget-ssl`；完整 wget / wget-nossl 在部分 OpenWrt 25.12 设备上会导致 apk 下载索引失败。
- 清理上次失败安装残留在 apk world 里的初始化包名，避免后续安装一直被缺失包阻塞。

## 0.3.2

- bootstrap 下载顺序改为主源、Gitee、GitHub，避免指定 Gitee 后无法回退 GitHub。
- 下载失败不再使用不兼容的 `wget --no-check-certificate`，除非当前 wget 明确支持。
- PassWall 相关脚本被 Gitee 返回 451 时不再阻塞菜单启动。

## 0.3.1

- bootstrap 下载子脚本时增加 GitHub/Gitee 双源 fallback，国内网络可直接用 `RAW_BASE` 指定 Gitee。
- 基础初始化不再安装会影响 HTTPS 下载的 `wget-nossl`，改用 `wget-ssl`。
- apk 安装失败时清理缓存、更新列表并重试一次，减少截断包导致的连续失败。

## 0.3.0

- 增加 iStore 软件中心安装入口，调用官方 `istore-reinstall.run`。
- 安装前限制架构，只允许 `x86_64` 和 `arm64` 设备继续执行。
- 菜单、命令行和 README 增加 `--istore` 用法。

## 0.2.0

- 增加 PassWall 自解压 `.run` 包构建脚本，默认打包 `x86_64`、`aarch64_generic`、`aarch64_a53`、`aarch64_a72`。
- 菜单增加 `/tmp/passwall-run` 本地 `.run` 安装入口。
- README 增加 `.run` 离线安装和维护者打包说明。

## 0.1.0

- 新建官方原版 OpenWrt 首次安装辅助项目。
- 增加菜单入口、基础初始化、overlay 扩容、PassWall 安装、Argon 主题、系统信息检查。
- 增加 Windows 电脑端 PassWall APK 离线下载工具。
