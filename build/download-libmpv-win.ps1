param(
  [string]$LibmpvDir = "$env:USERPROFILE\libmpv"
)

$ErrorActionPreference = "Stop"

$marker = "$LibmpvDir\include\mpv\client.h"
if (Test-Path $marker) {
  Write-Host "libmpv SDK already present at $LibmpvDir, skip download."
  exit 0
}

# 1) 获取最新 release 的 API 数据
Write-Host "Querying latest shinchiro/mpv-winbuild-cmake release..."
$api = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
$release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "ci-build" }

# 2) 在 assets 中匹配 mpv-dev-x86_64-*.7z（不带 v3，兼容普通 x64 CPU）
$asset = $release.assets |
  Where-Object { $_.name -match '^mpv-dev-x86_64-\d{8}-git-[0-9a-f]+\.7z$' } |
  Select-Object -First 1

if (-not $asset) {
  throw "No suitable mpv-dev-x86_64-*.7z asset found in latest release ($($release.tag_name))."
}

Write-Host "Selected asset: $($asset.name)"
Write-Host "Download URL  : $($asset.browser_download_url)"

$archive = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive

# 3) 解压（GitHub Windows runner 自带 7z）
Write-Host "Extracting to $LibmpvDir"
New-Item -ItemType Directory -Force -Path $LibmpvDir | Out-Null
7z x $archive -o"$LibmpvDir" -y | Out-Null

# 4) 标准化目录（部分包会多一层子目录）
if (-not (Test-Path "$LibmpvDir\include\mpv\client.h")) {
  $inner = Get-ChildItem $LibmpvDir -Directory | Select-Object -First 1
  if ($inner -and (Test-Path "$($inner.FullName)\include\mpv\client.h")) {
    Move-Item "$($inner.FullName)\*" $LibmpvDir -Force
    Remove-Item $inner.FullName -Force -Recurse
  }
}

# 5) 最终校验
$expected = @(
  "$LibmpvDir\include\mpv\client.h",
  "$LibmpvDir\lib\mpv.lib",
  "$LibmpvDir\bin\libmpv-2.dll"
)
$missing = $expected | Where-Object { -not (Test-Path $_) }
if ($missing) {
  throw "libmpv SDK incomplete, missing: $($missing -join ', ')"
}

Write-Host "libmpv SDK ready at $LibmpvDir (tag: $($release.tag_name))"
