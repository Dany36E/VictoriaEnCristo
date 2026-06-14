param(
    [string]$AssetsPath = "assets",
    [int]$Top = 30
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $AssetsPath)) {
    throw "Assets path not found: $AssetsPath"
}

$assetRoot = (Resolve-Path $AssetsPath).Path.TrimEnd('\', '/')
$files = Get-ChildItem -Path $AssetsPath -Recurse -File
$totalBytes = ($files | Measure-Object Length -Sum).Sum

Write-Host "Asset files: $($files.Count)"
Write-Host ("Total size: {0:N2} MB" -f ($totalBytes / 1MB))
Write-Host ""

Write-Host "Largest $Top assets"
$files |
    Sort-Object Length -Descending |
    Select-Object -First $Top |
    ForEach-Object {
        "{0,8:N2} MB  {1}" -f ($_.Length / 1MB), $_.FullName
    }

Write-Host ""
Write-Host "Size by top-level asset folder"
$files |
    Group-Object {
        $relative = $_.FullName.Substring($assetRoot.Length).TrimStart('\', '/')
        ($relative -split '[\\/]')[0]
    } |
    ForEach-Object {
        $sum = ($_.Group | Measure-Object Length -Sum).Sum
        [PSCustomObject]@{
            Folder = $_.Name
            Files  = $_.Count
            MB     = [math]::Round($sum / 1MB, 2)
        }
    } |
    Sort-Object MB -Descending |
    ForEach-Object {
        "{0,8:N2} MB  ({1,3} files)  {2}" -f $_.MB, $_.Files, $_.Folder
    }