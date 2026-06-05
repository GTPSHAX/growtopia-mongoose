
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Host "This script must be run as an administrator. Please run with elevated privileges." -ForegroundColor Red
  exit 1
}

netsh int ipv4 set dynamicport tcp start=1024 num=64511 | Out-Null
netsh int ipv4 set dynamicport udp start=1024 num=64511 | Out-Null
netsh int ipv6 set dynamicport tcp start=1024 num=64511 | Out-Null
netsh int ipv6 set dynamicport udp start=1024 num=64511 | Out-Null

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"


Set-ItemProperty -Path $regPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "MaxFreeTcbs" -Value 65536 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "MaxHashTableSize" -Value 65536 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "Tcp1323Opts" -Value 3 -Type DWord -Force

try {
  Enable-NetAdapterRss -Name "*" -ErrorAction SilentlyContinue | Out-Null
  Write-Host "RSS (Receive Side Scaling) sucessfully enabled on all virtual adapters." -ForegroundColor Green
} catch {
  Write-Host "Failed to enable RSS on some adapters. Please check your network adapter settings." -ForegroundColor Yellow
}


$fwPath = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters"
if (!(Test-Path $fwPath)) { New-Item -Path $fwPath -Force | Out-Null }
Set-ItemProperty -Path $fwPath -Name "DisableStatefulFTP" -Value 1 -Type DWord -Force

Write-Host "System tuning for high-load benchmarking completed successfully." -ForegroundColor Green
Write-Host "Please restart your computer for all changes to take effect." -ForegroundColor Green
