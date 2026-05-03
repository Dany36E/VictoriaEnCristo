param([int]$X = 1400, [int]$Y = 700, [int]$Ticks = 10, [int]$Delta = -120)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WH {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
$p = Get-Process app_quitar -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object -First 1
if ($p) { [WH]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }
Start-Sleep -Milliseconds 300
[WH]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 150
$wheelData = if ($Delta -lt 0) { [uint32](4294967296 + $Delta) } else { [uint32]$Delta }
for ($i = 0; $i -lt $Ticks; $i++) {
  [WH]::mouse_event(0x0800, 0, 0, $wheelData, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
}
Start-Sleep -Milliseconds 500
Write-Host "scrolled $Ticks ticks"
