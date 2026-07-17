# restore-db.ps1 — Variante Windows (test en dev local) du script de
# restauration. Équivalent fonctionnel de restore-db.sh, avec les mêmes
# garde-fous (confirmation explicite, vérification du fichier).
#
# Usage :
#   .\restore-db.ps1 -DumpFile .\backups\payflex_payflexdb_20260717_030000.zip
#   .\restore-db.ps1 -DumpFile <dump.zip> -TargetDb payflexdb_test
#   .\restore-db.ps1 -DumpFile <dump.zip> -Force
#
# ATTENTION : ce script ÉCRASE le contenu de la base cible. Irréversible.

param(
    [Parameter(Mandatory = $true)]
    [string]$DumpFile,

    [string]$TargetDb,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $name = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

function Write-Log {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

function Fail {
    param([string]$Message)
    Write-Log "ERREUR: $Message"
    exit 1
}

$DbHost     = if ($env:PAYFLEX_DB_HOST) { $env:PAYFLEX_DB_HOST } else { "localhost" }
$DbPort     = if ($env:PAYFLEX_DB_PORT) { $env:PAYFLEX_DB_PORT } else { "3306" }
$DbUser     = if ($env:PAYFLEX_DB_USER) { $env:PAYFLEX_DB_USER } else { "root" }
$DbPassword = if ($env:PAYFLEX_DB_PASSWORD) { $env:PAYFLEX_DB_PASSWORD } else { "" }
$DefaultDb  = if ($env:PAYFLEX_DB_NAME) { $env:PAYFLEX_DB_NAME } else { "payflexdb" }
if (-not $TargetDb) { $TargetDb = $DefaultDb }

# --- Garde-fou 1 : le fichier de dump doit exister --------------------------
if (-not (Test-Path $DumpFile)) { Fail "Fichier introuvable : $DumpFile" }

if (-not (Get-Command mysql -ErrorAction SilentlyContinue)) {
    Fail "client 'mysql.exe' introuvable dans le PATH."
}

# --- Décompression si .zip ---------------------------------------------------
$SqlFileToImport = $DumpFile
$TempExtractDir = $null
if ($DumpFile.ToLower().EndsWith(".zip")) {
    $TempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("payflex_restore_" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $TempExtractDir -Force | Out-Null
    Expand-Archive -Path $DumpFile -DestinationPath $TempExtractDir -Force
    $extracted = Get-ChildItem -Path $TempExtractDir -Filter "*.sql" | Select-Object -First 1
    if (-not $extracted) { Fail "Aucun fichier .sql trouvé dans l'archive $DumpFile" }
    $SqlFileToImport = $extracted.FullName
}

$CredsFile = [System.IO.Path]::GetTempFileName()
@"
[client]
user=$DbUser
password=$DbPassword
host=$DbHost
port=$DbPort
"@ | Set-Content -Path $CredsFile -Encoding ASCII

try {
    # --- Garde-fou 2 : la base cible existe-t-elle déjà ? -------------------
    $dbExists = & mysql "--defaults-extra-file=$CredsFile" -N -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$TargetDb';"

    Write-Log "Cible : base '$TargetDb' sur ${DbHost}:${DbPort} (existe déjà : $dbExists)"
    Write-Log "Fichier de dump : $DumpFile"

    # --- Garde-fou 3 : confirmation explicite -------------------------------
    if (-not $Force) {
        if ($dbExists -eq "1") {
            Write-Host ""
            Write-Host "/!\ ATTENTION : la base '$TargetDb' existe déjà et va être ECRASEE" -ForegroundColor Yellow
            Write-Host "    par le contenu de : $DumpFile" -ForegroundColor Yellow
            Write-Host "    Cette opération est IRREVERSIBLE (aucun rollback automatique)." -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "La base '$TargetDb' n'existe pas encore, elle sera créée puis peuplée." -ForegroundColor Cyan
            Write-Host ""
        }
        $confirmation = Read-Host "Tapez exactement CONFIRMER pour continuer"
        if ($confirmation -ne "CONFIRMER") {
            Write-Log "Restauration annulée par l'utilisateur (confirmation non reçue)."
            exit 1
        }
    }

    Write-Log "Création de la base '$TargetDb' si nécessaire..."
    & mysql "--defaults-extra-file=$CredsFile" -e "CREATE DATABASE IF NOT EXISTS ``$TargetDb`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    Write-Log "Démarrage de la restauration..."
    $start = Get-Date
    if ($TargetDb -ne $DefaultDb) {
        Get-Content $SqlFileToImport -Raw | & mysql "--defaults-extra-file=$CredsFile" --force $TargetDb
    } else {
        Get-Content $SqlFileToImport -Raw | & mysql "--defaults-extra-file=$CredsFile"
    }
    if ($LASTEXITCODE -ne 0) { Fail "La restauration a échoué (code $LASTEXITCODE)." }

    $elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Log "Restauration terminée en ${elapsed}s dans la base '$TargetDb'."
    Write-Log "Pensez à relancer le backend (Flyway vérifiera la cohérence du schéma au démarrage)."
}
finally {
    Remove-Item -Path $CredsFile -ErrorAction SilentlyContinue
    if ($TempExtractDir -and (Test-Path $TempExtractDir)) {
        Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
