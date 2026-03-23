# Запускать от имени администратора!
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Run as Administrator!"
    Read-Host "Press Enter to exit"
    exit
}

# Найти активный Wi-Fi адаптер (InterfaceType 71 = IEEE 802.11)
$adapter = Get-NetAdapter | Where-Object { $_.InterfaceType -eq 71 -and $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $adapter) {
    Write-Host "No active Wi-Fi adapter found:"
    Get-NetAdapter | Format-Table Name, InterfaceIndex, Status
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Adapter: $($adapter.Name)"
Write-Host ""
Write-Host "1 - DHCP"
Write-Host "2 - Static (192.168.1.50 / 255.255.255.0 / gw 192.168.1.1 / dns 8.8.8.8)"
Write-Host "3 - Adapter info (model, link, speed, duplex)"
$c = Read-Host ">"

if ($c -eq "1") {
    netsh interface ipv4 set address name="$($adapter.Name)" source=dhcp
    netsh interface ipv4 set dns    name="$($adapter.Name)" source=dhcp
}
if ($c -eq "2") {
    netsh interface ipv4 set address name="$($adapter.Name)" static 192.168.1.50 255.255.255.0 192.168.1.1
    netsh interface ipv4 set dns    name="$($adapter.Name)" static 8.8.8.8
}
if ($c -eq "3") {
    Write-Host "Model:      $($adapter.InterfaceDescription)"
    Write-Host "Link:       $($adapter.Status)"
    Write-Host "Speed:      $($adapter.LinkSpeed)"
    Write-Host "Full Duplex: $($adapter.FullDuplex)"
}

Read-Host "Press Enter to exit"
