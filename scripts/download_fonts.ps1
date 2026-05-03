$ErrorActionPreference = 'Continue'
$dest = 'google_fonts'
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$urls = @{
  'Manrope-VariableFont_wght.ttf'            = 'https://github.com/google/fonts/raw/main/ofl/manrope/Manrope%5Bwght%5D.ttf'
  'Cinzel-VariableFont_wght.ttf'             = 'https://github.com/google/fonts/raw/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf'
  'Lora-VariableFont_wght.ttf'               = 'https://github.com/google/fonts/raw/main/ofl/lora/Lora%5Bwght%5D.ttf'
  'Lora-Italic-VariableFont_wght.ttf'        = 'https://github.com/google/fonts/raw/main/ofl/lora/Lora-Italic%5Bwght%5D.ttf'
  'CrimsonPro-VariableFont_wght.ttf'         = 'https://github.com/google/fonts/raw/main/ofl/crimsonpro/CrimsonPro%5Bwght%5D.ttf'
  'CrimsonPro-Italic-VariableFont_wght.ttf'  = 'https://github.com/google/fonts/raw/main/ofl/crimsonpro/CrimsonPro-Italic%5Bwght%5D.ttf'
  'Lato-Regular.ttf'                         = 'https://github.com/google/fonts/raw/main/ofl/lato/Lato-Regular.ttf'
  'Lato-Bold.ttf'                            = 'https://github.com/google/fonts/raw/main/ofl/lato/Lato-Bold.ttf'
  'Lato-Italic.ttf'                          = 'https://github.com/google/fonts/raw/main/ofl/lato/Lato-Italic.ttf'
}

$ok = 0; $fail = 0
foreach ($entry in $urls.GetEnumerator()) {
  $name = $entry.Key
  $url  = $entry.Value
  try {
    Invoke-WebRequest -Uri $url -OutFile "$dest\$name" -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
    Write-Host "OK  $name"
    $ok++
  } catch {
    Write-Host "ERR $name : $($_.Exception.Message)"
    $fail++
  }
}
Write-Host "=== ok=$ok fail=$fail ==="
Get-ChildItem $dest | Select-Object Name,Length | Format-Table -AutoSize
