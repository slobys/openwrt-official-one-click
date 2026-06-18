@echo off
chcp 65001 >nul
setlocal

title PassWall APK 离线下载工具 - 一瓶奶油

set "TMPPS=%TEMP%\passwall_apk_%RANDOM%%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$lines=Get-Content -LiteralPath '%~f0'; $idx=[Array]::IndexOf($lines,'__POWERSHELL_BELOW__'); if($idx -lt 0){throw '没有找到 PowerShell 脚本标记'}; $ps=$lines[($idx+1)..($lines.Count-1)]; Set-Content -LiteralPath '%TMPPS%' -Value $ps -Encoding UTF8"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"

set "ERR=%ERRORLEVEL%"
del "%TMPPS%" >nul 2>nul

echo.
pause
exit /b %ERR%

__POWERSHELL_BELOW__

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " PassWall APK 离线下载工具" -ForegroundColor Cyan
Write-Host " YouTube频道：一瓶奶油" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "常见 CPU 架构示例：" -ForegroundColor Yellow
Write-Host " NanoPi R4S / R5S / R6S：aarch64_generic"
Write-Host " x86 软路由：x86_64"
Write-Host " 部分 MTK 路由器：aarch64_cortex-a53"
Write-Host " 老款 ARM 路由器：arm_cortex-a7_neon-vfpv4"
Write-Host " 老款 mipsel 路由器：mipsel_24kc"
Write-Host ""

$arch = Read-Host "请输入你的 CPU 架构，默认 aarch64_generic"
if ([string]::IsNullOrWhiteSpace($arch)) { $arch = "aarch64_generic" }

$version = Read-Host "请输入 OpenWrt 大版本，默认 25.12"
if ([string]::IsNullOrWhiteSpace($version)) { $version = "25.12" }

$desktop = [Environment]::GetFolderPath("Desktop")
$outDir = Join-Path $desktop "passwall-apk-$version-$arch-latest"
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
Remove-Item -Path (Join-Path $outDir "*.apk") -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "下载目录：" -ForegroundColor Green
Write-Host $outDir

function Get-SourceForgeFiles {
 param([string]$Repo)

 $rssUrl = "https://sourceforge.net/projects/openwrt-passwall-build/rss?path=/releases/packages-$version/$arch/$Repo"
 $folderUrl = "https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-$version/$arch/$Repo/"
 $files = @()

 Write-Host ""
 Write-Host "正在读取目录：$Repo" -ForegroundColor Cyan

 try {
  $rss = Invoke-WebRequest -Uri $rssUrl -UseBasicParsing -TimeoutSec 30
  [xml]$xml = $rss.Content
  foreach ($item in $xml.rss.channel.item) {
   $link = [string]$item.link
   $title = [string]$item.title
   $name = ""
   if ($link -match "/([^/]+\.apk)(/download)?($|\?)") {
    $name = [System.Uri]::UnescapeDataString($matches[1])
   } elseif ($title -match "([^/\\]+\.apk)$") {
    $name = [System.Uri]::UnescapeDataString($matches[1])
   }
   if ($name -ne "") {
    $files += [PSCustomObject]@{ Name = $name; Repo = $Repo }
   }
  }
 } catch {
  Write-Host "RSS 读取失败，继续尝试网页目录..." -ForegroundColor Yellow
 }

 try {
  $page = Invoke-WebRequest -Uri $folderUrl -UseBasicParsing -TimeoutSec 30
  $matches = [regex]::Matches($page.Content, '([A-Za-z0-9._+\-]+\.apk)')
  foreach ($m in $matches) {
   $name = [System.Uri]::UnescapeDataString($m.Groups[1].Value)
   if ($name -match '\.apk$') {
    $files += [PSCustomObject]@{ Name = $name; Repo = $Repo }
   }
  }
 } catch {
  Write-Host "网页目录读取失败：$Repo" -ForegroundColor Red
  Write-Host $_.Exception.Message
 }

 $files | Group-Object Name | ForEach-Object { $_.Group[0] }
}

function Get-VersionKey {
 param([string]$FileName)
 $nums = [regex]::Matches($FileName, '\d+') | ForEach-Object { [Int64]$_.Value }
 $key = ""
 foreach ($n in $nums) { $key += "{0:D20}." -f $n }
 $key
}

function Find-LatestPackage {
 param([array]$Files, [string]$Regex)
 $matched = $Files | Where-Object { $_.Name -match $Regex }
 if (!$matched -or $matched.Count -eq 0) { return $null }
 $matched | Sort-Object @{ Expression = { Get-VersionKey -FileName $_.Name }; Descending = $true } | Select-Object -First 1
}

function Test-ApkFile {
 param([string]$Path)
 if (!(Test-Path $Path)) { return $false }
 if ((Get-Item $Path).Length -lt 1024) { return $false }
 try {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $take = [Math]::Min($bytes.Length, 512)
  $head = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $take).ToLower()
  if ($head.Contains("<html") -or $head.Contains("<!doctype") -or $head.Contains("sourceforge")) { return $false }
  return $true
 } catch {
  return $true
 }
}

function Download-Package {
 param([object]$Pkg)
 if ($null -eq $Pkg) { return }

 $fileName = $Pkg.Name
 $repo = $Pkg.Repo
 $savePath = Join-Path $outDir $fileName
 $urls = @(
  "https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$version/$arch/$repo/$fileName",
  "https://downloads.sourceforge.net/project/openwrt-passwall-build/releases/packages-$version/$arch/$repo/$fileName",
  "https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-$version/$arch/$repo/$fileName/download"
 )

 Write-Host ""
 Write-Host "正在下载：$fileName" -ForegroundColor Cyan
 $ok = $false

 foreach ($url in $urls) {
  if ($ok) { break }
  try {
   Remove-Item $savePath -Force -ErrorAction SilentlyContinue
   $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
   if ($curl) {
    & curl.exe -L --retry 3 --connect-timeout 20 --ssl-no-revoke -o "$savePath" "$url"
   } else {
    Invoke-WebRequest -Uri $url -OutFile $savePath -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 60
   }
   if (Test-ApkFile -Path $savePath) {
    $size = (Get-Item $savePath).Length
    Write-Host "完成：$fileName 大小：$size 字节" -ForegroundColor Green
    $ok = $true
   } else {
    Write-Host "当前下载源异常，尝试下一个下载源..." -ForegroundColor Yellow
   }
  } catch {
   Write-Host "当前下载源失败，尝试下一个下载源..." -ForegroundColor Yellow
  }
 }

 if (!$ok) {
  Write-Host "下载失败：$fileName" -ForegroundColor Red
 }
}

$targets = @(
 @{ Name = "chinadns-ng"; Regex = "^chinadns-ng-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "dns2socks"; Regex = "^dns2socks-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "tcping"; Regex = "^tcping-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "geoview"; Regex = "^geoview-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "xray-core"; Regex = "^xray-core-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "sing-box"; Regex = "^sing-box-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "hysteria"; Regex = "^hysteria-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "v2ray-geoip"; Regex = "^v2ray-geoip-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "v2ray-geosite"; Regex = "^v2ray-geosite-[0-9].*\.apk$"; Repo = "passwall_packages" },
 @{ Name = "luci-app-passwall"; Regex = "^luci-app-passwall-[0-9].*\.apk$"; Repo = "passwall_luci" },
 @{ Name = "luci-i18n-passwall-zh-cn"; Regex = "^luci-i18n-passwall-zh-cn-[0-9].*\.apk$"; Repo = "passwall_luci" }
)

$repoCache = @{}
foreach ($target in $targets) {
 $repo = $target.Repo
 if (!$repoCache.ContainsKey($repo)) {
  $repoCache[$repo] = Get-SourceForgeFiles -Repo $repo
 }
}

$missing = @()
foreach ($target in $targets) {
 $pkg = Find-LatestPackage -Files $repoCache[$target.Repo] -Regex $target.Regex
 if ($null -eq $pkg) {
  Write-Host ""
  Write-Host "没有找到：$($target.Name)" -ForegroundColor Red
  $missing += $target.Name
 } else {
  Write-Host ""
  Write-Host "匹配到 $($target.Name)：$($pkg.Name)" -ForegroundColor Green
  Download-Package -Pkg $pkg
 }
}

$guide = @"
OpenWrt 安装命令：

1. 在软路由创建目录：
mkdir -p /tmp/passwall

2. 将本文件夹内所有 .apk 上传到：
/tmp/passwall

3. SSH 执行：
wget --no-check-certificate -qO /usr/bin/openwrt-easy https://raw.githubusercontent.com/slobys/openwrt-official-one-click/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy --passwall-local

如果 GitHub raw 慢，可改用 Gitee：
wget --no-check-certificate -qO /usr/bin/openwrt-easy https://gitee.com/naiyou88/openwrt-official-one-click/raw/main/bootstrap.sh && chmod +x /usr/bin/openwrt-easy && openwrt-easy --passwall-local

也可以直接执行：
cd /tmp/passwall
apk add --allow-untrusted ./*.apk
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
"@

$guidePath = Join-Path $outDir "OpenWrt安装说明.txt"
$guide | Out-File -FilePath $guidePath -Encoding UTF8

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "下载完成" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "文件保存位置：" -ForegroundColor Green
Write-Host $outDir

if ($missing.Count -gt 0) {
 Write-Host ""
 Write-Host "以下包没有找到：" -ForegroundColor Yellow
 foreach ($m in $missing) { Write-Host " $m" }
}

Write-Host ""
Write-Host "已生成安装说明：OpenWrt安装说明.txt" -ForegroundColor Green
Start-Process $outDir
