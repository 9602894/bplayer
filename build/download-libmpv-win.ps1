param(
  [string]$LibmpvDir = "$env:USERPROFILE\libmpv"
)

$ErrorActionPreference = "Stop"

# 1) 获取最新 release
Write-Host "Querying latest shinchiro/mpv-winbuild-cmake release..."
$api = "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
$release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "ci-build" }

$asset = $release.assets |
  Where-Object { $_.name -match '^mpv-dev-x86_64-\d{8}-git-[0-9a-f]+\.7z$' } |
  Select-Object -First 1

if (-not $asset) { throw "No suitable mpv-dev-x86_64-*.7z asset found." }
Write-Host "Downloading: $($asset.browser_download_url)"

$archive = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive

# 2) 解压到临时目录，避免直接污染目标目录
$tempDir = Join-Path $env:TEMP "libmpv-extract-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
7z x $archive -o"$tempDir" -y | Out-Null

# 3) 递归定位关键文件（包内布局可能不固定）
Write-Host "Locating libmpv files in extracted archive..."
$dll      = Get-ChildItem $tempDir -Recurse -Filter "libmpv-2.dll" | Select-Object -First 1
$header   = Get-ChildItem $tempDir -Recurse -Filter "client.h" | Where-Object { $_.DirectoryName -like "*mpv*" } | Select-Object -First 1
$defFile  = Get-ChildItem $tempDir -Recurse -Filter "libmpv.def" | Select-Object -First 1
$dllA     = Get-ChildItem $tempDir -Recurse -Filter "libmpv.dll.a" | Select-Object -First 1
$mpvLib   = Get-ChildItem $tempDir -Recurse -Filter "mpv.lib" | Select-Object -First 1

if (-not $dll)    { throw "libmpv-2.dll not found in archive." }
if (-not $header) { throw "mpv/client.h not found in archive." }

# 4) 按 electron-mpv-video 的约定重组目录：include / lib / bin
Write-Host "Arranging SDK into $LibmpvDir ..."
Remove-Item $LibmpvDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path `
  "$LibmpvDir\include\mpv", "$LibmpvDir\lib", "$LibmpvDir\bin" | Out-Null

# 头文件
Copy-Item $header.DirectoryName\* "$LibmpvDir\include\mpv" -Recurse -Force

# DLL
Copy-Item $dll.FullName "$LibmpvDir\bin\libmpv-2.dll" -Force

# 5) 生成/放置 MSVC 导入库 mpv.lib
$targetLib = "$LibmpvDir\lib\mpv.lib"

if ($mpvLib) {
  Write-Host "mpv.lib already present in archive, copying."
  Copy-Item $mpvLib.FullName $targetLib -Force
}
elseif ($defFile) {
  Write-Host "Generating mpv.lib from libmpv.def via lib.exe ..."
  $libExe = Get-Command lib.exe -ErrorAction SilentlyContinue
  if (-not $libExe) {
    throw "lib.exe not found. Ensure Visual Studio Build Tools (C++ workload) is installed on the runner."
  }
  Push-Location $defFile.DirectoryName
  & lib.exe /def:libmpv.def /out:mpv.lib /machine:x64
  Pop-Location
  Copy-Item (Join-Path $defFile.DirectoryName "mpv.lib") $targetLib -Force
}
elseif ($dllA) {
  Write-Host "Only MinGW import lib (libmpv.dll.a) found. Copying as mpv.lib (best-effort)."
  Copy-Item $dllA.FullName $targetLib -Force
}
else {
  throw "Cannot produce mpv.lib: no mpv.lib, libmpv.def, or libmpv.dll.a found in archive."
}

# 6) 最终校验
$expected = @(
  "$LibmpvDir\include\mpv\client.h",
  "$LibmpvDir\lib\mpv.lib",
  "$LibmpvDir\bin\libmpv-2.dll"
)
$missing = $expected | Where-Object { -not (Test-Path $_) }
if ($missing) { throw "SDK incomplete, missing: $($missing -join ', ')" }

Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue
Write-Host "libmpv SDK ready at $LibmpvDir"
