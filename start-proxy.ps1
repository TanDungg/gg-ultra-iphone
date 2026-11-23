$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$venvDir  = Join-Path $PSScriptRoot ".venv"
$venvPy   = Join-Path $venvDir "Scripts\python.exe"
$mitmdump = Join-Path $venvDir "Scripts\mitmdump.exe"
$reqFile  = Join-Path $PSScriptRoot "requirements.txt"
$script   = Join-Path $PSScriptRoot "g1_acq_mitm.py"
$port     = 8080

if (-not (Test-Path $mitmdump)) {
    Write-Host "Chua co .venv hoac mitmproxy. Dang tu dong cai dat lan dau..." -ForegroundColor Yellow

    $pyCmd = $null
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $pyCmd = @("py", "-3")
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        $pyCmd = @("python")
    } else {
        Write-Error "May chua co Python 3. Hay cai Python (winget install Python.Python.3.12 hoac tai tai python.org) roi chay lai."
    }

    if (-not (Test-Path $venvPy)) {
        if ($pyCmd.Count -gt 1) {
            & $pyCmd[0] $pyCmd[1] -m venv $venvDir
        } else {
            & $pyCmd[0] -m venv $venvDir
        }
        if ($LASTEXITCODE -ne 0) { throw "Tao .venv that bai." }
    }

    & $venvPy -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "Nang cap pip that bai." }

    & $venvPy -m pip install -r $reqFile
    if ($LASTEXITCODE -ne 0) { throw "Cai dat mitmproxy that bai." }
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
