param([string]$Flutter = 'C:\Users\danie\flutter\bin\flutter.bat')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    & $Flutter test --no-pub test/visual --reporter expanded
    $testExit = $LASTEXITCODE
    & (Join-Path $PSScriptRoot 'build_qa_gallery.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'QA gallery generation failed.' }
    if ($testExit -ne 0) { throw 'Visual QA failed. Inspect build/qa screenshots and test output.' }
    Write-Output 'Visual QA passed. Screenshots: build/qa. This does not certify native Android/iOS behavior.'
} finally {
    Pop-Location
}
