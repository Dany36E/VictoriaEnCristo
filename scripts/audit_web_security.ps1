[CmdletBinding()]
param(
  [string]$WebRoot = (Join-Path $PSScriptRoot '..\docs'),
  [string]$FirebaseConfig = (Join-Path $PSScriptRoot '..\firebase.json')
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) {
  $failures.Add($Message)
}

function Assert-NoMatch(
  [System.IO.FileInfo[]]$Files,
  [string]$Pattern,
  [string]$Description
) {
  foreach ($file in $Files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    if ([regex]::IsMatch($text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      Add-Failure "$Description en $($file.FullName)"
    }
  }
}

$resolvedWebRoot = (Resolve-Path -LiteralPath $WebRoot).Path
$htmlFiles = @(Get-ChildItem -LiteralPath $resolvedWebRoot -Filter '*.html' -File)
$scriptFiles = @(Get-ChildItem -LiteralPath $resolvedWebRoot -Filter '*.js' -File)
$styleFiles = @(Get-ChildItem -LiteralPath $resolvedWebRoot -Filter '*.css' -File)
$publicFiles = @(Get-ChildItem -LiteralPath $resolvedWebRoot -Recurse -File)

if ($htmlFiles.Count -eq 0) {
  Add-Failure 'No se encontraron páginas HTML para auditar.'
}

# La web pública es deliberadamente estática: no acepta datos ni carga terceros.
Assert-NoMatch $htmlFiles '<\s*(form|iframe|object|embed|video|audio)\b' 'Elemento interactivo o incrustado no permitido'
Assert-NoMatch $htmlFiles '<script(?![^>]*\bsrc\s*=)[^>]*>' 'Script en línea no permitido'
Assert-NoMatch $htmlFiles '<style\b|\sstyle\s*=' 'CSS en línea no permitido'
Assert-NoMatch $htmlFiles '\son[a-z]+\s*=' 'Manejador de evento HTML no permitido'
Assert-NoMatch $htmlFiles '(?:src|href)\s*=\s*["'']https?://' 'Recurso o navegación remota no permitida'
Assert-NoMatch $htmlFiles 'javascript\s*:' 'URL javascript: no permitida'
Assert-NoMatch $scriptFiles '(^|[^A-Za-z])(eval\s*\(|new\s+Function\s*\(|document\.write\s*\(|innerHTML\s*=|outerHTML\s*=|insertAdjacentHTML\s*\()' 'Sumidero DOM peligroso no permitido'
Assert-NoMatch $scriptFiles '(localStorage|sessionStorage|document\.cookie|indexedDB|sendBeacon|XMLHttpRequest|WebSocket|fetch\s*\()' 'Almacenamiento, rastreo o red del cliente no permitidos'
Assert-NoMatch $styleFiles '@import\s+url|url\(\s*["'']?https?://' 'Dependencia CSS remota no permitida'

$forbiddenPublicNames = @(
  '.env',
  'firebase.json',
  'package.json',
  'package-lock.json',
  'google-services.json',
  'GoogleService-Info.plist'
)
$forbiddenPublicExtensions = @('.map', '.pem', '.key', '.p12', '.jks', '.keystore', '.ts', '.dart')
foreach ($file in $publicFiles) {
  if ($forbiddenPublicNames -contains $file.Name) {
    Add-Failure "Archivo sensible dentro del directorio público: $($file.FullName)"
  }
  if ($forbiddenPublicExtensions -contains $file.Extension) {
    Add-Failure "Tipo de archivo no permitido dentro del directorio público: $($file.FullName)"
  }
}

$config = Get-Content -LiteralPath $FirebaseConfig -Raw | ConvertFrom-Json
$headers = @{}
foreach ($rule in @($config.hosting.headers)) {
  if ($rule.source -eq '**') {
    foreach ($header in @($rule.headers)) {
      $headers[$header.key.ToLowerInvariant()] = [string]$header.value
    }
  }
}

$requiredHeaders = @(
  'content-security-policy',
  'x-content-type-options',
  'referrer-policy',
  'permissions-policy',
  'cross-origin-opener-policy',
  'x-frame-options',
  'x-permitted-cross-domain-policies'
)
foreach ($required in $requiredHeaders) {
  if (-not $headers.ContainsKey($required)) {
    Add-Failure "Falta el encabezado HTTP $required."
  }
}

$csp = $headers['content-security-policy']
foreach ($directive in @(
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self'",
  "connect-src 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "object-src 'none'",
  'upgrade-insecure-requests'
)) {
  if (-not $csp.Contains($directive)) {
    Add-Failure "La CSP no contiene: $directive"
  }
}
if ($csp.Contains("'unsafe-inline'") -or $csp.Contains("'unsafe-eval'")) {
  Add-Failure 'La CSP contiene unsafe-inline o unsafe-eval.'
}
if ($headers['x-content-type-options'] -ne 'nosniff') {
  Add-Failure 'X-Content-Type-Options debe ser nosniff.'
}
if ($headers['x-frame-options'] -ne 'DENY') {
  Add-Failure 'X-Frame-Options debe ser DENY.'
}

if ($failures.Count -gt 0) {
  Write-Error ("Auditoría web fallida:`n- " + ($failures -join "`n- "))
  exit 1
}

Write-Host "Auditoría web aprobada: $($htmlFiles.Count) páginas, $($scriptFiles.Count) script(s), $($styleFiles.Count) hoja(s) y $($publicFiles.Count) archivos revisados en docs."
Write-Host 'Sin formularios, iframes, rastreo, almacenamiento web, recursos remotos, scripts/CSS en línea ni sumideros DOM peligrosos.'
Write-Host 'CSP estricta y encabezados defensivos presentes en firebase.json.'
