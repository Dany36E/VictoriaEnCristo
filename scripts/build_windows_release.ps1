param(
    [switch]$Zip,
    [switch]$Install,
    [switch]$CreateDesktopShortcut,
    [string]$GoogleDesktopClientId = $env:GOOGLE_DESKTOP_CLIENT_ID,
    [string]$GoogleDesktopClientSecret = $env:GOOGLE_DESKTOP_CLIENT_SECRET
)

$ErrorActionPreference = "Stop"

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
flutter @buildArgs

$releaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    throw "Windows release folder not found: $releaseDir"
}

Write-Host "Release folder: $releaseDir"

if ($Zip) {
    $zipPath = "build\VictoriaEnCristo-Windows.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath
    Write-Host "Zip created: $zipPath"
}

if ($Install) {
    Write-Host "Installing / updating local Windows app shortcut..."
    & "$PSScriptRoot\install_windows_app.ps1" -CreateDesktopShortcut:$CreateDesktopShortcut
}

Write-Host "Done. Keep the .exe next to the data/ folder and DLL files."
