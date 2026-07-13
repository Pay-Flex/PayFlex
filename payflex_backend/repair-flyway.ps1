# Répare l'historique Flyway après une migration échouée (ex. V47).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$envFile = Join-Path $PSScriptRoot ".env"
$dbUrl = "jdbc:mysql://localhost:3306/payflexdb"
$dbUser = "root"
$dbPassword = ""

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $name = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        switch ($name) {
            "PAYFLEX_DB_URL" { if ($value) { $dbUrl = $value } }
            "PAYFLEX_DB_USER" { if ($value) { $dbUser = $value } }
            "PAYFLEX_DB_PASSWORD" { $dbPassword = $value }
        }
    }
}

Write-Host "Flyway repair sur $dbUrl (user=$dbUser)..." -ForegroundColor Cyan
$flywayArgs = @(
    "-q",
    "org.flywaydb:flyway-maven-plugin:10.20.1:repair",
    "-Dflyway.url=$dbUrl",
    "-Dflyway.user=$dbUser",
    "-Dflyway.password=$dbPassword",
    "-Dflyway.locations=classpath:db/migration"
)
& mvn @flywayArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Repair termine. Relancez .\run-local.ps1" -ForegroundColor Green
