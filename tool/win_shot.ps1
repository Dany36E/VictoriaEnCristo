param([string]$Name = 'shot', [int]$Max = 900)
$out = Join-Path (Get-Location) "test_screenshots\$Name.png"
$small = Join-Path (Get-Location) "test_screenshots\${Name}_s.png"
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WSy2 {
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@ -ErrorAction SilentlyContinue
$p = Get-Process app_quitar -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($null -eq $p) { Write-Host "no app"; exit 1 }
[WSy2]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
[WSy2]::BringWindowToTop($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 250
$rect = New-Object WSy2+RECT
[WSy2]::DwmGetWindowAttribute($p.MainWindowHandle, 9, [ref]$rect, [Runtime.InteropServices.Marshal]::SizeOf([type][WSy2+RECT])) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
python -c "from PIL import Image; im = Image.open(r'$out'); im.thumbnail(($Max, $Max)); im.save(r'$small')"
Write-Host "Saved $small ($w x $h)"

