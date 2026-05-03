param(
    [string]$TargetPath = "assets/images/headbanz",
    [switch]$Apply,
    [int]$OptimizationLevel = 3
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TargetPath)) {
    throw "Target path not found: $TargetPath"
}

if ($OptimizationLevel -lt 1 -or $OptimizationLevel -gt 6) {
    throw "OptimizationLevel must be between 1 and 6. Use 2-4 for conservative QA."
}

$optimizer = $null
$optimizerName = $null

$oxipng = Get-Command oxipng -ErrorAction SilentlyContinue
if ($oxipng) {
    $optimizer = $oxipng.Source
    $optimizerName = "oxipng"
}

if (-not $optimizer) {
    $optipng = Get-Command optipng -ErrorAction SilentlyContinue
    if ($optipng) {
        $optimizer = $optipng.Source
        $optimizerName = "optipng"
    }
}

$files = Get-ChildItem -Path $TargetPath -Filter *.png -File
if ($files.Count -eq 0) {
    throw "No PNG files found in $TargetPath"
}

$originalBytes = ($files | Measure-Object Length -Sum).Sum
$backupRoot = Join-Path ".asset_backups" ("headbanz_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

if (-not $optimizer) {
    Write-Warning "No lossless PNG optimizer found. Install oxipng or optipng. This script intentionally refuses lossy tools by default."
    if ($Apply) {
        throw "Cannot apply optimization without oxipng or optipng."
    }
    Write-Host "Files: $($files.Count)"
    Write-Host ("Original size: {0:N2} MB" -f ($originalBytes / 1MB))
    Write-Host "Dry run only. No files changed."
    return
}

Write-Host "Optimizer: $optimizerName"
Write-Host "Files: $($files.Count)"
Write-Host ("Original size: {0:N2} MB" -f ($originalBytes / 1MB))

if (-not $Apply) {
    Write-Host "Dry run only. Re-run with -Apply to create a backup and optimize losslessly."
    return
}

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

foreach ($file in $files) {
    Copy-Item -Path $file.FullName -Destination (Join-Path $backupRoot $file.Name) -Force
    if ($optimizerName -eq "oxipng") {
        & $optimizer "--opt" $OptimizationLevel "--strip" "safe" $file.FullName | Out-Null
    } else {
        & $optimizer "-o$OptimizationLevel" $file.FullName | Out-Null
    }
}

$optimizedFiles = Get-ChildItem -Path $TargetPath -Filter *.png -File
$optimizedBytes = ($optimizedFiles | Measure-Object Length -Sum).Sum
$savedBytes = $originalBytes - $optimizedBytes

Write-Host ("Optimized size: {0:N2} MB" -f ($optimizedBytes / 1MB))
Write-Host ("Saved: {0:N2} MB ({1:N2}%)" -f ($savedBytes / 1MB), (($savedBytes / $originalBytes) * 100))
Write-Host "Backup: $backupRoot"
Write-Host "QA: compare at least 5 cards visually before deleting the backup."