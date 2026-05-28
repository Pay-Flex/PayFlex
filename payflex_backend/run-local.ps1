# Démarre le backend en chargeant les secrets depuis .env (non versionné).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "Fichier .env introuvable. Copiez .env.example vers .env et renseignez vos clés FedaPay." -ForegroundColor Yellow
    exit 1
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $name = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
    Write-Host "  charge : $name" -ForegroundColor DarkGray
}

Write-Host "Demarrage PayFlex backend (port 8088)..." -ForegroundColor Cyan
Write-Host "Logs erreurs : erreur.log | diagnostic.log | mobile-api.log (dans ce dossier)" -ForegroundColor DarkGray
mvn spring-boot:run
