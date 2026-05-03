Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WG3 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@
$p = Get-Process app_quitar -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object -First 1
if (-not $p) { Write-Host "no app"; exit 1 }
$r = New-Object WG3+RECT
[WG3]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
"GW L=$($r.Left) T=$($r.Top) R=$($r.Right) B=$($r.Bottom) W=$($r.Right - $r.Left) H=$($r.Bottom - $r.Top)"
$r2 = New-Object WG3+RECT
[WG3]::DwmGetWindowAttribute($p.MainWindowHandle, 9, [ref]$r2, 16) | Out-Null
"DWM L=$($r2.Left) T=$($r2.Top) R=$($r2.Right) B=$($r2.Bottom) W=$($r2.Right - $r2.Left) H=$($r2.Bottom - $r2.Top)"
