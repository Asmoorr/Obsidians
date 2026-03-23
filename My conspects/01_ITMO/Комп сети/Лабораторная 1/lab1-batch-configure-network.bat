@echo off
chcp 1251 >nul

for /f %%i in ('powershell -NoProfile -Command "Get-NetAdapter -Physical | Where-Object { $_.PhysicalMediaType -like '*802.11*' -and $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty InterfaceIndex"') do set "IF=%%i"

if not defined IF (
    echo Active Wi-Fi adapter not found.
    netsh interface show interface
    pause
    exit /b
)

echo Adapter index: %IF%
echo.
echo 1 - DHCP
echo 2 - Static (192.168.1.50 / 255.255.255.0 / gw 192.168.1.1)
set /p c="> "

if "%c%"=="1" (
    netsh interface ipv4 set address name=%IF% source=dhcp
    netsh interface ipv4 set dns    name=%IF% source=dhcp
)
if "%c%"=="2" (
    netsh interface ipv4 set address name=%IF% static 192.168.1.50 255.255.255.0 192.168.1.1
    netsh interface ipv4 set dns    name=%IF% static 8.8.8.8
)

pause
