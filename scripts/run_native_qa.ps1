param(
    [Parameter(Mandatory = $true)][string]$Device,
    [string]$Flutter = 'C:\Users\danie\flutter\bin\flutter.bat',
    [ValidateSet('series', 'access')][string]$Suite = 'series'
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    # Resolve plugins: a previous release build can omit integration_test.
    & $Flutter drive --driver=test_driver/visual_qa_driver.dart "--target=integration_test/${Suite}_native_qa_test.dart" -d $Device
    if ($LASTEXITCODE -ne 0) { throw 'Native QA failed. Inspect test output and build/qa/native.' }
    Write-Output "Native $Suite QA passed. Inspect build/qa/native screenshots separately."
} finally {
    Pop-Location
}
