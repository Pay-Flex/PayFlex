# Récupère les logs PayFlex mobile depuis un téléphone Android connecté en USB.
$ErrorActionPreference = "Stop"
$pkg = "com.payflex.app.payflex_mobile"
$remoteDir = "/data/data/$pkg/app_flutter/payflex_logs"
$localDir = Join-Path $PSScriptRoot "..\logs_mobile"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "adb introuvable. Installez Android SDK platform-tools." -ForegroundColor Red
    exit 1
}

$devices = adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "Aucun appareil Android détecté (adb devices)." -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $localDir | Out-Null

Write-Host "Copie des logs depuis $remoteDir ..." -ForegroundColor Cyan
adb shell "run-as $pkg cat $remoteDir/payflex_errors.log" 2>$null | Set-Content -Encoding utf8 (Join-Path $localDir "payflex_errors.log")
adb shell "run-as $pkg cat $remoteDir/payflex_api.log" 2>$null | Set-Content -Encoding utf8 (Join-Path $localDir "payflex_api.log")

Write-Host "Logs enregistrés dans : $localDir" -ForegroundColor Green
Get-ChildItem $localDir -Filter "*.log" | ForEach-Object {
    $kb = [math]::Round($_.Length / 1KB, 1)
    Write-Host "  $($_.Name) ($kb Ko)" -ForegroundColor DarkGray
}
