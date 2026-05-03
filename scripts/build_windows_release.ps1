param(
    [switch]$Zip
)

$ErrorActionPreference = "Stop"

Write-Host "Building Victoria en Cristo for Windows..."
flutter build windows --release

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

Write-Host "Done. Keep the .exe next to the data/ folder and DLL files."