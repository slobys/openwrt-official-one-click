@echo off
chcp 65001 >nul
setlocal

title PassWall RUN 离线包下载工具 - 一瓶奶油

set "TMPPS=%TEMP%\passwall_run_%RANDOM%%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$lines=Get-Content -LiteralPath '%~f0'; $idx=[Array]::IndexOf($lines,'__POWERSHELL_BELOW__'); if($idx -lt 0){throw '没有找到 PowerShell 脚本标记'}; $ps=$lines[($idx+1)..($lines.Count-1)]; Set-Content -LiteralPath '%TMPPS%' -Value $ps -Encoding UTF8"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"

set "ERR=%ERRORLEVEL%"
del "%TMPPS%" >nul 2>nul

echo.
pause
exit /b %ERR%

__POWERSHELL_BELOW__

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " PassWall RUN 离线包下载工具" -ForegroundColor Cyan
Write-Host " YouTube频道：一瓶奶油" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "可选架构：" -ForegroundColor Yellow
Write-Host " 1. x86_64"
Write-Host " 2. aarch64_generic"
Write-Host " 3. aarch64_a53"
Write-Host " 4. aarch64_a72"
Write-Host ""

$choice = Read-Host "请输入序号或架构名，默认 2"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "2" }

switch ($choice.Trim()) {
 "1" { $arch = "x86_64" }
 "2" { $arch = "aarch64_generic" }
 "3" { $arch = "aarch64_a53" }
 "4" { $arch = "aarch64_a72" }
 default { $arch = $choice.Trim() }
}

if ($arch -notin @("x86_64", "aarch64_generic", "aarch64_a53", "aarch64_a72")) {
 throw "不支持的架构：$arch"
}

$api = "https://api.github.com/repos/slobys/openwrt-official-one-click/releases/latest"
Write-Host ""
Write-Host "正在读取 GitHub 最新 Release..." -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "passwall-run-downloader" } -TimeoutSec 30
$asset = $release.assets | Where-Object { $_.name -match "^PassWall_.*_$([regex]::Escape($arch))_all_sdk_.*\.run$" } | Select-Object -First 1
if ($null -eq $asset) {
 throw "最新 Release 没有找到 $arch 的 .run 文件"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$outDir = Join-Path $desktop "passwall-run"
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$savePath = Join-Path $outDir $asset.name

Write-Host "匹配到：" -ForegroundColor Green
Write-Host $asset.name
Write-Host ""
Write-Host "正在下载到：" -ForegroundColor Cyan
Write-Host $savePath

$ok = $false
$urls = @(
 $asset.browser_download_url,
 ("https://gh-proxy.com/" + $asset.browser_download_url)
)

foreach ($url in $urls) {
 if ($ok) { break }
 try {
  Remove-Item $savePath -Force -ErrorAction SilentlyContinue
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
   & curl.exe -L --retry 3 --connect-timeout 20 --ssl-no-revoke -o "$savePath" "$url"
  } else {
   Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 300
  }
  if ((Test-Path $savePath) -and ((Get-Item $savePath).Length -gt 1024)) {
   $ok = $true
  }
 } catch {
  Write-Host "当前下载源失败，尝试下一个下载源..." -ForegroundColor Yellow
 }
}

if (!$ok) {
 throw "下载失败"
}

$guide = @"
OpenWrt 安装命令：

1. 在软路由创建目录：
mkdir -p /tmp/passwall-run

2. 将这个 .run 文件上传到：
/tmp/passwall-run

3. SSH 执行：
wget --no-check-certificate -qO /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy --passwall-run

也可以直接执行：
sh /tmp/passwall-run/$($asset.name)
"@

$guidePath = Join-Path $outDir "OpenWrt安装说明.txt"
$guide | Out-File -FilePath $guidePath -Encoding UTF8

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "下载完成" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "文件保存位置：" -ForegroundColor Green
Write-Host $outDir
Write-Host ""
Write-Host "已生成安装说明：OpenWrt安装说明.txt" -ForegroundColor Green
Start-Process $outDir
