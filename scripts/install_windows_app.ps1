param(
    [string]$SourceDir = "build\windows\x64\runner\Release",
    [string]$AppName = "Victoria en Cristo",
    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourcePath = Resolve-Path (Join-Path $repoRoot $SourceDir)
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\$AppName"
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuDir "$AppName.lnk"
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$AppName.lnk"
$versionFile = Join-Path $installRoot "version.txt"
$exeName = "app_quitar.exe"
$exePath = Join-Path $installRoot $exeName
$sourceExe = Join-Path $sourcePath $exeName

if (-not (Test-Path $sourceExe)) {
    throw "No se encontró el ejecutable de Windows en: $sourceExe"
}

$versionLine = (Get-Content (Join-Path $repoRoot "pubspec.yaml") | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1)
$version = ($versionLine -replace '^version:\s*', '').Trim()
if ([string]::IsNullOrWhiteSpace($version)) {
    $version = "unknown"
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null

Get-ChildItem -LiteralPath $installRoot -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $sourcePath '*') -Destination $installRoot -Recurse -Force

$ws = New-Object -ComObject WScript.Shell

$shortcut = $ws.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installRoot
$shortcut.WindowStyle = 1
$shortcut.Description = $AppName
$shortcut.IconLocation = $exePath
$shortcut.Save()

if ($CreateDesktopShortcut) {
    $desktopShortcut = $ws.CreateShortcut($desktopShortcutPath)
    $desktopShortcut.TargetPath = $exePath
    $desktopShortcut.WorkingDirectory = $installRoot
    $desktopShortcut.WindowStyle = 1
    $desktopShortcut.Description = $AppName
    $desktopShortcut.IconLocation = $exePath
    $desktopShortcut.Save()
}

Set-Content -LiteralPath $versionFile -Value $version -Encoding UTF8

Write-Host "Installed: $AppName"
Write-Host "Version: $version"
Write-Host "Path: $installRoot"
Write-Host "Start Menu shortcut: $shortcutPath"
if ($CreateDesktopShortcut) {
    Write-Host "Desktop shortcut: $desktopShortcutPath"
}
