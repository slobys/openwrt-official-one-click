# Changelog

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
