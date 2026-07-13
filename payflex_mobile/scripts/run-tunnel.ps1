# Lance l'app mobile via LocalTunnel (HTTPS public, tests 4G / webhooks FedaPay).
#
# Prérequis :
#   - Node.js (npx)
#   - Terminal 1 : cd payflex_backend ; .\run-local.ps1
#   - Terminal 2 : npx localtunnel --port 8088 --subdomain payflex-app
#   - payflex_backend/.env : PAYFLEX_PUBLIC_URL=https://payflex-app.loca.lt
#
# Usage :
#   .\scripts\run-tunnel.ps1
#   .\scripts\run-tunnel.ps1 -d R5CT437FF1R
#   .\scripts\run-tunnel.ps1 -TunnelUrl "https://payflex-app.loca.lt"
#
param(
    [string]$TunnelUrl = "https://payflex-app.loca.lt"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not $TunnelUrl) {
    Write-Host "TunnelUrl requis (ex. https://payflex-app.loca.lt)." -ForegroundColor Red
    exit 1
}

Write-Host "Mode LocalTunnel : $TunnelUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ordre de demarrage (3 terminaux) :" -ForegroundColor Yellow
Write-Host "  1. cd payflex_backend ; .\run-local.ps1" -ForegroundColor DarkGray
Write-Host "  2. npx localtunnel --port 8088 --subdomain payflex-app" -ForegroundColor DarkGray
Write-Host "  3. Ce script (Flutter)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Backend .env : PAYFLEX_PUBLIC_URL=$TunnelUrl" -ForegroundColor DarkGray
Write-Host "Test sante : curl -H `"Bypass-Tunnel-Reminder: true`" $TunnelUrl/api/mobile/health" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Production : build -Mode prod -ApiBase https://api.votredomaine.com (pas de tunnel)." -ForegroundColor DarkGray
Write-Host "Lancement Flutter (PAYFLEX_USE_TUNNEL=true)..." -ForegroundColor Cyan

fvm flutter run `
  --dart-define=PAYFLEX_USE_TUNNEL=true `
  --dart-define=PAYFLEX_TUNNEL_BASE=$TunnelUrl `
  @args
