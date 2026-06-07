param(
    [switch]$Zip,
    [switch]$Install,
    [switch]$CreateDesktopShortcut,
    [string]$GoogleDesktopClientId = $env:GOOGLE_DESKTOP_CLIENT_ID,
    [string]$GoogleDesktopClientSecret = $env:GOOGLE_DESKTOP_CLIENT_SECRET
)

$ErrorActionPreference = "Stop"

$pubspecPath = "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at repository root."
}

$versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?$' } | Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?$') {
    throw "Could not parse app version from pubspec.yaml."
}

$buildName = $Matches[1]
$versionTag = "v$buildName"

$localEnvPath = ".env.desktop"
if (Test-Path $localEnvPath) {
    Get-Content $localEnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) { return }
        $parts = $line.Split("=", 2)
        if ($parts.Length -ne 2) { return }
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        if ($key -eq "GOOGLE_DESKTOP_CLIENT_ID" -and [string]::IsNullOrWhiteSpace($GoogleDesktopClientId)) {
            $GoogleDesktopClientId = $value
        }
        if ($key -eq "GOOGLE_DESKTOP_CLIENT_SECRET" -and [string]::IsNullOrWhiteSpace($GoogleDesktopClientSecret)) {
            $GoogleDesktopClientSecret = $value
        }
    }
}

Write-Host "Building Victoria en Cristo for Windows..."
$buildArgs = @("build", "windows", "--release")
if (-not [string]::IsNullOrWhiteSpace($GoogleDesktopClientId) -and
    -not [string]::IsNullOrWhiteSpace($GoogleDesktopClientSecret)) {
    $buildArgs += "--dart-define=GOOGLE_DESKTOP_CLIENT_ID=$GoogleDesktopClientId"
    $buildArgs += "--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=$GoogleDesktopClientSecret"
    Write-Host "Google Desktop OAuth: configured for this build."
} else {
    Write-Warning "Google Desktop OAuth not configured. Create .env.desktop or pass -GoogleDesktopClientId/-GoogleDesktopClientSecret."
}

$flutterExe = (Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if ([string]::IsNullOrWhiteSpace($flutterExe)) {
    $flutterExe = "C:\Users\danie\flutter\bin\flutter.bat"
}
if (-not (Test-Path $flutterExe)) {
    throw "Flutter executable not found. Expected flutter in PATH or at C:\Users\danie\flutter\bin\flutter.bat"
}
& $flutterExe @buildArgs

$releaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    throw "Windows release folder not found: $releaseDir"
}

Write-Host "Release folder: $releaseDir"

if ($Zip) {
    $zipPath = "build\VictoriaEnCristo-Windows.zip"
    $versionedZipPath = "build\VictoriaEnCristo-Windows-$versionTag.zip"
    $distZipPath = "dist\VictoriaEnCristo-Windows-$versionTag.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath
    Write-Host "Zip created: $zipPath"
    New-Item -ItemType Directory -Force "dist" | Out-Null
    Copy-Item $zipPath $versionedZipPath -Force
    Copy-Item $zipPath $distZipPath -Force
    Write-Host "Versioned zip copied to: $versionedZipPath"
    Write-Host "Versioned zip copied to: $distZipPath"
}

if ($Install) {
    Write-Host "Installing / updating local Windows app shortcut..."
    & "$PSScriptRoot\install_windows_app.ps1" -CreateDesktopShortcut:$CreateDesktopShortcut
}

Write-Host "Done. Keep the .exe next to the data/ folder and DLL files."
