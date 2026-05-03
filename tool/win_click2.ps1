param([int]$X, [int]$Y, [int]$DelayMs = 800)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Mc2 {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public int mouseData; public int dwFlags; public int time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public int type; public MOUSEINPUT mi; public long pad; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int cbSize);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
}
'@ -ErrorAction SilentlyContinue
$p = Get-Process app_quitar -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($null -ne $p) { [Mc2]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }
Start-Sleep -Milliseconds 200

# Use absolute coordinates normalized to 0..65535 across virtual screen
$sw = [Mc2]::GetSystemMetrics(0)
$sh = [Mc2]::GetSystemMetrics(1)
$ax = [int]([double]$X / $sw * 65535)
$ay = [int]([double]$Y / $sh * 65535)

[Mc2]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 80

$MOVE = 0x0001; $ABSOLUTE = 0x8000; $DOWN = 0x0002; $UP = 0x0004
$inputs = @(
  (New-Object Mc2+INPUT -Property @{ type = 0; mi = (New-Object Mc2+MOUSEINPUT -Property @{ dx = $ax; dy = $ay; dwFlags = ($MOVE -bor $ABSOLUTE) }) }),
  (New-Object Mc2+INPUT -Property @{ type = 0; mi = (New-Object Mc2+MOUSEINPUT -Property @{ dwFlags = $DOWN }) }),
  (New-Object Mc2+INPUT -Property @{ type = 0; mi = (New-Object Mc2+MOUSEINPUT -Property @{ dwFlags = $UP }) })
)
[Mc2]::SendInput([uint32]$inputs.Count, $inputs, [Runtime.InteropServices.Marshal]::SizeOf([type][Mc2+INPUT])) | Out-Null

Start-Sleep -Milliseconds $DelayMs
Write-Host "Clicked $X,$Y (abs $ax,$ay screen $sw x $sh)"
