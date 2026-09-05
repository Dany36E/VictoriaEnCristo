$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$qaRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../build/qa'))
if (-not (Test-Path -LiteralPath $qaRoot)) { throw 'Run QA before building the gallery.' }
$sourceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'lib') -Recurse -File -Filter '*.dart'
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'test/visual') -Recurse -File -Filter '*.dart'
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'integration_test') -File -Filter '*_native_qa_test.dart'
    Get-Item -LiteralPath (Join-Path $projectRoot 'assets/content/series.json')
)
$latestSourceUtc = ($sourceFiles | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
$staleCount = 0
$cards = foreach ($file in Get-ChildItem -LiteralPath $qaRoot -Recurse -File -Filter '*.png') {
    $relative = [IO.Path]::GetRelativePath($qaRoot, $file.FullName).Replace('\', '/')
    $label = [Net.WebUtility]::HtmlEncode($relative)
    $uri = ($relative.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $stamp = [Net.WebUtility]::HtmlEncode($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    $isStale = $file.LastWriteTimeUtc -lt $latestSourceUtc
    if ($isStale) { $staleCount++ }
    $state = if ($isStale) { "<strong class='stale-label'>DESACTUALIZADA</strong><br>" } else { '' }
    $class = if ($isStale) { 'stale' } else { 'fresh' }
    "<figure class='$class'><a href='$uri'><img loading='lazy' src='$uri' alt='$label'></a><figcaption>$state$label<br><small>$stamp</small></figcaption></figure>"
}
$captureCount = @($cards).Count
$sourceStamp = [Net.WebUtility]::HtmlEncode($latestSourceUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))
$html = @"
<!doctype html><html lang='es'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Victoria en Cristo — revisión visual</title>
<style>body{font:16px system-ui;margin:24px;background:#111923;color:#f6f0e5}h1{font-size:26px}p{max-width:900px;line-height:1.5}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:20px}figure{margin:0;padding:12px;background:#203044;border:2px solid transparent;border-radius:8px}figure.stale{border-color:#e25f5f;opacity:.72}img{width:100%;height:430px;object-fit:contain;background:#0c121a}figcaption{overflow-wrap:anywhere;padding-top:12px}.stale-label{color:#ff9a9a;font-size:12px;letter-spacing:.08em}small{color:#bdc9d8}a{color:inherit}</style>
<h1>Victoria en Cristo — revisión visual</h1>
<p>Capturas locales de pruebas. Pulsa una imagen para verla completa. Cada captura conserva la fecha de su última ejecución; una imagen por sí sola no prueba que el caso pasó. Consulta los logs y matrix-results.json. Los perfiles del mismo emulador no representan dispositivos físicos diferentes, y los tamaños de iPad no certifican iOS.</p>
<p><strong>$captureCount capturas; $staleCount desactualizadas.</strong> Código de referencia más reciente: $sourceStamp. Una captura se marca desactualizada cuando es anterior al código o al arnés de QA actual.</p>
<main>$($cards -join "`n")</main></html>
"@
$path = Join-Path $qaRoot 'index.html'
Set-Content -LiteralPath $path -Value $html -Encoding UTF8
Write-Output "Gallery: $path"
