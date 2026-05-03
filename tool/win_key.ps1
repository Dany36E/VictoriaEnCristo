param([string]$Key = '{ESC}')
$p = Get-Process app_quitar -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object -First 1
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FG { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd); }
'@
if ($p) { [FG]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait($Key)
Start-Sleep -Milliseconds 600
Write-Host "sent $Key"
