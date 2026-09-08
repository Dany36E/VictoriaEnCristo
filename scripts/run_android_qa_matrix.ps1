param(
    [ValidatePattern('^emulator-\d+$')][string]$Device = 'emulator-5554',
    [string]$Flutter = 'C:\Users\danie\flutter\bin\flutter.bat',
    [string]$Adb = 'C:\Users\danie\AppData\Local\Android\Sdk\platform-tools\adb.exe',
    [ValidateSet('phone_small', 'tablet')][string[]]$Profiles = @('phone_small', 'tablet'),
    [ValidateSet('series', 'access')][string[]]$Suites = @('series', 'access')
)
$ErrorActionPreference = 'Stop'
$previousProfile = $env:QA_DEVICE_PROFILE
# Keep the requested logical dimensions while rendering fewer physical pixels.
# This is a layout-stress matrix; the default emulator run separately covers
# a high-density Android device. Lower pixel counts make software-rendered CI
# emulators much less likely to disconnect between suites.
$matrix = @{
    phone_small = @{ size = '320x568'; density = '160' }
    tablet = @{ size = '768x1024'; density = '160' }
}
function Invoke-AdbChecked([string[]]$AdbArgs) {
    $result = & $Adb -s $Device @AdbArgs
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $AdbArgs" }
    return $result
}
function Test-AndroidDevice {
    & $Adb -s $Device get-state 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if ((Invoke-AdbChecked @('shell', 'getprop', 'ro.kernel.qemu')).Trim() -ne '1') {
        throw 'Only an Android emulator may be resized.'
    }
    $originalSize = (Invoke-AdbChecked @('shell', 'wm', 'size')) -join "`n"
    $originalDensity = (Invoke-AdbChecked @('shell', 'wm', 'density')) -join "`n"
    $restoreSize = if ($originalSize -match 'Override size:\s*(\d+x\d+)') { $Matches[1] } else { 'reset' }
    $restoreDensity = if ($originalDensity -match 'Override density:\s*(\d+)') { $Matches[1] } else { 'reset' }
    $results = @()
    $restorePending = $false
    try {
        foreach ($profile in $Profiles) {
            $settings = $matrix[$profile]
            Invoke-AdbChecked @('shell', 'wm', 'size', $settings.size)
            Invoke-AdbChecked @('shell', 'wm', 'density', $settings.density)
            $env:QA_DEVICE_PROFILE = $profile
            $directory = "build/qa/native/$profile"
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
            foreach ($suite in $Suites) {
                Write-Output "Testing $suite on $profile ($($settings.size), $($settings.density) dpi)"
                $flutterArgs = @(
                    'drive',
                    '--driver=test_driver/visual_qa_driver.dart',
                    "--target=integration_test/${suite}_native_qa_test.dart",
                    '-d',
                    $Device
                )
                if ($suite -eq 'access' -and $env:QA_TEXT_SCALE -and $env:QA_TEXT_SCALE -ne 'all') {
                    $flutterArgs += "--dart-define=QA_TEXT_SCALE=$($env:QA_TEXT_SCALE)"
                }
                $logPath = "$directory/$suite.log"
                & $Flutter @flutterArgs *> $logPath
                $driverExit = $LASTEXITCODE
                $logText = Get-Content -LiteralPath $logPath -Raw
                $testsPassed = $logText -match '(?m)(?:^|:)\s*All tests passed!\s*$'
                $teardownDisconnect = $driverExit -ne 0 -and
                    $testsPassed -and
                    $logText -match 'Service has disappeared|device offline'
                $effectiveExit = if ($driverExit -eq 0 -or $teardownDisconnect) { 0 } else { $driverExit }
                $warning = if ($teardownDisconnect) {
                    'Emulator disconnected only after the Flutter test runner confirmed all tests passed.'
                } else {
                    $null
                }
                $results += [pscustomobject]@{
                    profile=$profile
                    suite=$suite
                    exitCode=$effectiveExit
                    driverExitCode=$driverExit
                    verifiedByTestLog=$testsPassed
                    teardownWarning=$warning
                    size=$settings.size
                    density=$settings.density
                    completedAt=(Get-Date).ToString('o')
                }
                $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath 'build/qa/native/matrix-results.json'
                if ($teardownDisconnect) {
                    Write-Warning "$profile/$suite passed, but the emulator disconnected during driver cleanup."
                }
                Write-Output "Result $profile/$suite : effective exit $effectiveExit (driver exit $driverExit)"
            }
        }
    } finally {
        if (Test-AndroidDevice) {
            Invoke-AdbChecked @('shell', 'wm', 'size', $restoreSize)
            Invoke-AdbChecked @('shell', 'wm', 'density', $restoreDensity)
        } else {
            $restorePending = $true
            [pscustomobject]@{
                device = $Device
                size = $restoreSize
                density = $restoreDensity
                reason = 'Device disconnected before restoration'
                recordedAt = (Get-Date).ToString('o')
            } | ConvertTo-Json | Set-Content -LiteralPath 'build/qa/native/restore-pending.json'
            Write-Warning 'Emulator disconnected. Restoration instructions saved to build/qa/native/restore-pending.json.'
        }
    }
    $hasTestFailure = $results.Where({ $_.exitCode -ne 0 }).Count -gt 0
    $hasUnverifiedRestoreFailure = $restorePending -and
        $results.Where({ $_.verifiedByTestLog -ne $true }).Count -gt 0
    if ($hasTestFailure -or $hasUnverifiedRestoreFailure) {
        throw 'Native matrix is incomplete or has failures; inspect matrix-results.json, profile logs and restore-pending.json.'
    }
} finally {
    $env:QA_DEVICE_PROFILE = $previousProfile
    Pop-Location
}
