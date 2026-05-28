# Lance l'app mobile en Wi-Fi LAN — URL stable http://<IP_PC>:8088
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$hostIp = $env:PAYFLEX_API_HOST
if (-not $hostIp) {
    $wifi = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -match '^192\.168\.' -or $_.IPAddress -match '^10\.' } |
        Select-Object -First 1
    if ($wifi) { $hostIp = $wifi.IPAddress }
}
if (-not $hostIp) {
    $hostIp = "192.168.1.68"
    Write-Host "IP non détectée — défaut $hostIp (ipconfig pour vérifier)." -ForegroundColor Yellow
}

Write-Host "Backend attendu sur http://${hostIp}:8088 (run-local.ps1 + même Wi-Fi)." -ForegroundColor DarkGray
Write-Host "Lancement Flutter (PAYFLEX_API_HOST=$hostIp)..." -ForegroundColor Cyan
flutter run --dart-define=PAYFLEX_API_HOST=$hostIp @args
