# Lance l'app mobile via USB (adb reverse) — URL stable 127.0.0.1:8088
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "adb introuvable. Installez Android SDK platform-tools." -ForegroundColor Red
    exit 1
}

$deviceLines = @(adb devices | Select-String "`tdevice$")
if ($deviceLines.Count -gt 1 -and -not ($args -match '-d\b')) {
    Write-Host "Plusieurs appareils connectes — precisez l'ID :" -ForegroundColor Yellow
    adb devices -l
    Write-Host "Ex. : .\scripts\run-usb.ps1 -d R5CT437FF1R" -ForegroundColor Yellow
}

$adbArgs = @()
if ($args -match '-d\s+(\S+)') {
    $adbArgs = @('-s', $Matches[1])
}

Write-Host "Configuration du reverse USB (8088)..." -ForegroundColor Cyan
& adb @adbArgs reverse tcp:8088 tcp:8088

Write-Host "Backend attendu sur localhost:8088 (run-local.ps1 sur le PC)." -ForegroundColor DarkGray
Write-Host "IP stable 127.0.0.1 — pas de changement apres switch Wi-Fi." -ForegroundColor DarkGray
Write-Host "Lancement Flutter (PAYFLEX_USB_REVERSE=true)..." -ForegroundColor Cyan
fvm flutter run --dart-define=PAYFLEX_USB_REVERSE=true @args
