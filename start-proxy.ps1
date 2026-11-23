$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$mitmdump = Join-Path $PSScriptRoot ".venv\Scripts\mitmdump.exe"
$script   = Join-Path $PSScriptRoot "g1_acq_mitm.py"
$port     = 8080

if (-not (Test-Path $mitmdump)) {
    Write-Error "Khong tim thay $mitmdump. Hay chay lai lenh cai mitmproxy vao .venv."
}

$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet' -and $_.IPAddress -notmatch '^169\.254\.' } |
    Select-Object -ExpandProperty IPAddress

Write-Host "=== G1 ACQ MITM Proxy ===" -ForegroundColor Cyan
Write-Host "Chon IP ben duoi dien vao muc Wi-Fi Proxy tren iPhone (Port: $port):"
foreach ($ip in $ips) {
    Write-Host "  - $ip : $port" -ForegroundColor Green
}
Write-Host "Chi giai ma HTTPS cho: one.google.com (App Store / iCloud duoc bo qua nguyen ban)" -ForegroundColor Gray
Write-Host "Nhan Ctrl+C de dung proxy.`n" -ForegroundColor Yellow

& $mitmdump -s $script --listen-port $port --allow-hosts "^(one\.google\.com|mitm\.it)(:\d+)?$"
