param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk",
    [string]$GoogleServicesPath = "android\app\google-services.json",
    [string]$PackageName = "com.victoriaencristo.app"
)

$ErrorActionPreference = "Stop"

function Normalize-Sha1([string]$value) {
    return ($value -replace "[^0-9A-Fa-f]", "").ToLowerInvariant()
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$apkFullPath = Join-Path $repoRoot $ApkPath
$googleServicesFullPath = Join-Path $repoRoot $GoogleServicesPath

if (-not (Test-Path $apkFullPath)) {
    throw "APK not found: $ApkPath. Build it first with: flutter build apk --release"
}

if (-not (Test-Path $googleServicesFullPath)) {
    throw "google-services.json not found: $GoogleServicesPath"
}

$localPropertiesPath = Join-Path $repoRoot "android\local.properties"
$sdkDir = $env:ANDROID_HOME
if ([string]::IsNullOrWhiteSpace($sdkDir)) {
    $sdkDir = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($sdkDir) -and (Test-Path $localPropertiesPath)) {
    $sdkLine = Get-Content $localPropertiesPath | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
    if ($sdkLine) {
        $sdkDir = ($sdkLine -split '=', 2)[1].Trim().Replace('\\', '\')
    }
}

if ([string]::IsNullOrWhiteSpace($sdkDir) -or -not (Test-Path $sdkDir)) {
    throw "Android SDK not found. Set ANDROID_HOME or check android/local.properties."
}

$apksigner = Get-ChildItem (Join-Path $sdkDir "build-tools") -Recurse -Filter apksigner.bat -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($apksigner) -or -not (Test-Path $apksigner)) {
    throw "apksigner.bat not found under Android SDK build-tools."
}

$certOutput = & $apksigner verify --print-certs $apkFullPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "apksigner failed:`n$certOutput"
}

$sha1Line = $certOutput | Where-Object { $_ -match 'Signer #1 certificate SHA-1 digest:\s*([0-9A-Fa-f]+)' } | Select-Object -First 1
if (-not $sha1Line -or $sha1Line.ToString() -notmatch 'Signer #1 certificate SHA-1 digest:\s*([0-9A-Fa-f]+)') {
    throw "Could not read SHA-1 from APK signer output:`n$certOutput"
}
$apkSha1 = Normalize-Sha1 $Matches[1]

$googleServices = Get-Content $googleServicesFullPath -Raw | ConvertFrom-Json
$client = $googleServices.client |
    Where-Object { $_.client_info.android_client_info.package_name -eq $PackageName } |
    Select-Object -First 1

if (-not $client) {
    throw "Package $PackageName was not found in $GoogleServicesPath."
}

$registeredSha1 = @(
    $client.oauth_client |
        Where-Object { $_.android_info -and $_.android_info.package_name -eq $PackageName -and $_.android_info.certificate_hash } |
        ForEach-Object { Normalize-Sha1 $_.android_info.certificate_hash }
) | Sort-Object -Unique

Write-Host "Package: $PackageName"
Write-Host "APK SHA-1: $apkSha1"
Write-Host "Registered SHA-1 values in google-services.json:"
$registeredSha1 | ForEach-Object { Write-Host "  - $_" }

if ($registeredSha1 -notcontains $apkSha1) {
    throw @"
Google Sign-In is likely to fail with ApiException: 10.

The APK signing SHA-1 is not registered in Firebase for $PackageName.
Add this SHA-1 and its SHA-256 in Firebase Console -> Project settings -> Android app -> Add fingerprint:

SHA-1: $apkSha1

Then download the updated google-services.json, replace android/app/google-services.json, rebuild, and share the new APK/AAB.
"@
}

Write-Host "OK: APK signing SHA-1 is registered for Google Sign-In."
Write-Host "Important for Play testing: also add the Play Console > App integrity > App signing key certificate SHA-1/SHA-256 to Firebase. Play re-signs tester installs with that certificate."