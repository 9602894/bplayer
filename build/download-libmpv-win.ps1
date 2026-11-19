param(
  [string]$LibmpvDir = "$env:USERPROFILE\libmpv",
  [string]$Version = "20261111"
)

$ErrorActionPreference = "Stop"
$archive = "$env:TEMP\mpv-dev.7z"
$url = "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/$Version/mpv-dev-x86_64-$Version-git.7z"

if (Test-Path "$LibmpvDir\include\mpv\client.h") {
  Write-Host "libmpv SDK already present at $LibmpvDir, skip download."
  exit 0
}

Write-Host "Downloading libmpv dev package from $url"
Invoke-WebRequest -Uri $url -OutFile $archive

Write-Host "Extracting to $LibmpvDir"
7z x $archive -o"$LibmpvDir" -y

# 标准化目录：部分 release 解压后多一层目录，这里按实际结构调整
if (-not (Test-Path "$LibmpvDir\include\mpv\client.h")) {
  $inner = Get-ChildItem $LibmpvDir -Directory | Select-Object -First 1
  if ($inner -and (Test-Path "$inner.FullName\include\mpv\client.h")) {
    Move-Item "$($inner.FullName)\*" $LibmpvDir -Force
    Remove-Item $inner.FullName -Force -Recurse
  }
}

Write-Host "libmpv SDK ready:"
Get-ChildItem "$LibmpvDir\include\mpv\client.h", "$LibmpvDir\lib\mpv.lib", "$LibmpvDir\bin\libmpv-2.dll" -ErrorAction SilentlyContinue
