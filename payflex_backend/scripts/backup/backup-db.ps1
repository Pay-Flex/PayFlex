# backup-db.ps1 — Variante Windows (test en dev local) du script de sauvegarde.
# Équivalent fonctionnel de backup-db.sh : mysqldump + compression + rétention
# GFS (grandfather-father-son). Compression en .zip (Compress-Archive, natif
# PowerShell) au lieu de gzip (non disponible nativement sous Windows) —
# en production Linux, préférez backup-db.sh (.sql.gz).
#
# Usage :
#   .\backup-db.ps1
#
# Prérequis : mysqldump.exe dans le PATH (fourni avec MySQL Server / Workbench
# / XAMPP — ex: C:\Program Files\MySQL\MySQL Server 8.0\bin).
#
# Variables : charge .env dans ce dossier s'il existe (voir .env.example),
# sinon valeurs par défaut alignées sur payflex_backend/.env.example.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    if ($env:PAYFLEX_BACKUP_LOG_FILE) {
        $dir = Split-Path -Parent $env:PAYFLEX_BACKUP_LOG_FILE
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $env:PAYFLEX_BACKUP_LOG_FILE -Value $line
    }
}

function Fail {
    param([string]$Message)
    Write-Log "ERREUR: $Message"
    exit 1
}

# --- Chargement .env local (dossier scripts/backup/) ------------------------
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

$DbHost     = if ($env:PAYFLEX_DB_HOST) { $env:PAYFLEX_DB_HOST } else { "localhost" }
$DbPort     = if ($env:PAYFLEX_DB_PORT) { $env:PAYFLEX_DB_PORT } else { "3306" }
$DbName     = if ($env:PAYFLEX_DB_NAME) { $env:PAYFLEX_DB_NAME } else { "payflexdb" }
$DbUser     = if ($env:PAYFLEX_DB_USER) { $env:PAYFLEX_DB_USER } else { "root" }
$DbPassword = if ($env:PAYFLEX_DB_PASSWORD) { $env:PAYFLEX_DB_PASSWORD } else { "" }

$BackupDir = if ($env:PAYFLEX_BACKUP_DIR) { $env:PAYFLEX_BACKUP_DIR } else { Join-Path $PSScriptRoot "backups" }
$RetentionDaily   = [int](if ($env:PAYFLEX_BACKUP_RETENTION_DAILY) { $env:PAYFLEX_BACKUP_RETENTION_DAILY } else { 7 })
$RetentionWeekly  = [int](if ($env:PAYFLEX_BACKUP_RETENTION_WEEKLY) { $env:PAYFLEX_BACKUP_RETENTION_WEEKLY } else { 4 })
$RetentionMonthly = [int](if ($env:PAYFLEX_BACKUP_RETENTION_MONTHLY) { $env:PAYFLEX_BACKUP_RETENTION_MONTHLY } else { 3 })

if (-not (Get-Command mysqldump -ErrorAction SilentlyContinue)) {
    Fail "mysqldump.exe introuvable dans le PATH. Ajoutez le dossier bin de MySQL Server au PATH."
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$SqlFile  = Join-Path $BackupDir "payflex_${DbName}_${Timestamp}.sql"
$ZipFile  = Join-Path $BackupDir "payflex_${DbName}_${Timestamp}.zip"

Write-Log "Démarrage sauvegarde de la base '$DbName' ($DbHost`:$DbPort) -> $ZipFile"

# Fichier d'identifiants temporaire (évite le mot de passe en ligne de commande).
$CredsFile = [System.IO.Path]::GetTempFileName()
try {
    @"
[client]
user=$DbUser
password=$DbPassword
host=$DbHost
port=$DbPort
"@ | Set-Content -Path $CredsFile -Encoding ASCII

    & mysqldump "--defaults-extra-file=$CredsFile" --single-transaction --quick --routines --triggers --events --default-character-set=utf8mb4 --databases $DbName | Out-File -FilePath $SqlFile -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Path $SqlFile -ErrorAction SilentlyContinue
        Fail "mysqldump a échoué (code $LASTEXITCODE) — aucune sauvegarde partielle conservée."
    }

    Compress-Archive -Path $SqlFile -DestinationPath $ZipFile -Force
    Remove-Item -Path $SqlFile

    $sizeKb = [math]::Round((Get-Item $ZipFile).Length / 1KB, 1)
    Write-Log "Sauvegarde terminée : $ZipFile (${sizeKb} KB)"
}
finally {
    Remove-Item -Path $CredsFile -ErrorAction SilentlyContinue
}

# --- Upload hors-site optionnel (rclone), si installé -----------------------
$RcloneRemote = $env:PAYFLEX_BACKUP_RCLONE_REMOTE
$RclonePath = $env:PAYFLEX_BACKUP_RCLONE_PATH
if ($RcloneRemote) {
    if (Get-Command rclone -ErrorAction SilentlyContinue) {
        Write-Log "Upload hors-site via rclone vers ${RcloneRemote}:${RclonePath}..."
        & rclone copy $ZipFile "${RcloneRemote}:${RclonePath}" --log-level ERROR
        if ($LASTEXITCODE -eq 0) { Write-Log "Upload hors-site réussi." }
        else { Write-Log "ERREUR: échec de l'upload hors-site (backup local conservé)." }
    } else {
        Write-Log "AVERTISSEMENT: rclone configuré mais introuvable dans le PATH — upload ignoré."
    }
} else {
    Write-Log "Upload hors-site désactivé (PAYFLEX_BACKUP_RCLONE_REMOTE vide) — voir README.md."
}

# --- Rétention GFS (mêmes règles que backup-db.sh) --------------------------
Write-Log "Application de la politique de rétention (quotidien=${RetentionDaily}j, hebdo=${RetentionWeekly}sem, mensuel=${RetentionMonthly}mois)..."

$Now = Get-Date
$WeeklyMaxAgeDays = $RetentionDaily + ($RetentionWeekly * 7)
$MonthlyMaxAgeDays = $RetentionDaily + ($RetentionWeekly * 7) + ($RetentionMonthly * 31)

$deletedCount = 0
Get-ChildItem -Path $BackupDir -Filter "payflex_*.zip" | ForEach-Object {
    if ($_.BaseName -match '_(\d{8})_\d{6}$') {
        $datePart = $Matches[1]
        $fileDate = [DateTime]::ParseExact($datePart, "yyyyMMdd", $null)
        $ageDays = ($Now - $fileDate).Days
        $dayOfWeek = $fileDate.DayOfWeek   # Sunday, Monday, ...
        $dayOfMonth = $fileDate.Day

        $keep = $false
        if ($ageDays -le $RetentionDaily) { $keep = $true }
        elseif ($dayOfWeek -eq [DayOfWeek]::Sunday -and $ageDays -le $WeeklyMaxAgeDays) { $keep = $true }
        elseif ($dayOfMonth -eq 1 -and $ageDays -le $MonthlyMaxAgeDays) { $keep = $true }

        if (-not $keep) {
            Write-Log "Suppression sauvegarde expirée : $($_.Name) (âge ${ageDays}j)"
            Remove-Item -Path $_.FullName -Force
            $deletedCount++
        }
    }
}

Write-Log "Rétention appliquée : $deletedCount sauvegarde(s) expirée(s) supprimée(s)."
Write-Log "Sauvegarde terminée avec succès."
