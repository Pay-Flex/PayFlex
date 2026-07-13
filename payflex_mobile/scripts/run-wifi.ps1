# Lance l'app mobile en Wi-Fi LAN — URL stable http://<IP_PC>:8088
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

. (Join-Path $PSScriptRoot "lib\Get-PayflexLanIp.ps1")

$hostIp = Get-PayflexLanIp
if (-not $hostIp) {
    Write-Host "IP LAN introuvable." -ForegroundColor Red
    Write-Host "  1. Connectez le PC au Wi-Fi (même réseau que le téléphone)." -ForegroundColor Yellow
    Write-Host "  2. ipconfig → repérez l'IPv4 (ex. 192.168.0.42)." -ForegroundColor Yellow
    Write-Host "  3. Relancez : `$env:PAYFLEX_API_HOST='192.168.x.x'; .\scripts\run-wifi.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "Backend attendu sur http://${hostIp}:8088 (run-local.ps1 + même Wi-Fi)." -ForegroundColor DarkGray
Write-Host "IP LAN detectee : $hostIp" -ForegroundColor Green
Write-Host "L'app enregistre l'IP au 1er lancement (prefs). Changement de Wi-Fi :" -ForegroundColor DarkGray
Write-Host "  appui long sur le logo (ecran connexion) — pas de rebuild." -ForegroundColor DarkGray
Write-Host "Lancement Flutter (seed PAYFLEX_API_HOST=$hostIp si prefs vide)..." -ForegroundColor Cyan
fvm flutter run `
  --dart-define=PAYFLEX_API_HOST=$hostIp `
  --dart-define=PAYFLEX_API_HOST_SET=true `
  @args
