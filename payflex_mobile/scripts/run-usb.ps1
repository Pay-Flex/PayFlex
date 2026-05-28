# Lance l'app mobile via USB (adb reverse) — URL stable 127.0.0.1:8088
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "adb introuvable. Installez Android SDK platform-tools." -ForegroundColor Red
    exit 1
}

Write-Host "Configuration du reverse USB (8088)..." -ForegroundColor Cyan
adb reverse tcp:8088 tcp:8088

Write-Host "Backend attendu sur localhost:8088 (run-local.ps1 sur le PC)." -ForegroundColor DarkGray
Write-Host "Lancement Flutter (PAYFLEX_USB_REVERSE=true)..." -ForegroundColor Cyan
flutter run --dart-define=PAYFLEX_USB_REVERSE=true @args
