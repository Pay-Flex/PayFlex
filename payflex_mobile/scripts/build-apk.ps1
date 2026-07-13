# Génère l'APK release PayFlex (Android).
#
# Par défaut : APK universel (armeabi-v7a + arm64-v8a) installable sur tous les téléphones.
#
# Exemples :
#   .\scripts\build-apk.ps1
#   .\scripts\build-apk.ps1 -SplitPerAbi
#   .\scripts\build-apk.ps1 -PerAbi
#   .\scripts\build-apk.ps1 -TunnelUrl "https://payflex-app.loca.lt" -SplitPerAbi
#   .\scripts\build-apk.ps1 -Mode wifi -LanHost "192.168.1.68"
#   .\scripts\build-apk.ps1 -Mode prod -ApiBase "https://api.votredomaine.com"
#
param(
    [ValidateSet("tunnel", "wifi", "prod")]
    [string]$Mode = "tunnel",

    [string]$TunnelUrl = "https://payflex-app.loca.lt",
    [string]$LanHost = "",
    [string]$ApiBase = "",

    [ValidateSet("apk", "appbundle")]
    [string]$Target = "apk",

    [Alias("PerAbi")]
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

. (Join-Path $PSScriptRoot "lib\Get-PayflexLanIp.ps1")

# Architectures ARM couvrant les téléphones 32 et 64 bits (hors émulateurs x86).
$PhoneTargetPlatforms = "android-arm,android-arm64"

function Get-ApkAbiFolders {
    param([string]$ApkPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $ApkPath).Path)
    try {
        $zip.Entries |
            Where-Object { $_.FullName -match '^lib/([^/]+)/' } |
            ForEach-Object { $Matches[1] } |
            Sort-Object -Unique
    } finally {
        $zip.Dispose()
    }
}

$defines = @()

switch ($Mode) {
    "tunnel" {
        if (-not $TunnelUrl) {
            throw "TunnelUrl requis en mode tunnel."
        }
        $defines += "PAYFLEX_USE_TUNNEL=true"
        $defines += "PAYFLEX_TUNNEL_BASE=$TunnelUrl"
        Write-Host "Mode tunnel : $TunnelUrl" -ForegroundColor Cyan
        Write-Host "Backend + npx localtunnel doivent tourner sur le PC pendant les tests." -ForegroundColor DarkGray
    }
    "wifi" {
        if (-not $LanHost) {
            $LanHost = Get-PayflexLanIp
        }
        if (-not $LanHost) {
            throw "IP LAN introuvable. Passez -LanHost 192.168.x.x"
        }
        $defines += "PAYFLEX_USE_LAN=true"
        $defines += "PAYFLEX_API_HOST=$LanHost"
        $defines += "PAYFLEX_API_HOST_SET=true"
        Write-Host "Mode Wi-Fi LAN : http://${LanHost}:8088" -ForegroundColor Cyan
    }
    "prod" {
        if (-not $ApiBase) {
            throw "ApiBase requis en mode prod (ex. https://api.payflex.tg)."
        }
        $defines += "PAYFLEX_API_BASE=$ApiBase"
        $defines += "PAYFLEX_PROD_BUILD=true"
        Write-Host "Mode prod : $ApiBase" -ForegroundColor Cyan
        Write-Host "Override SharedPreferences ignore en release — URL compilee uniquement." -ForegroundColor DarkGray
    }
}

$defineArgs = $defines | ForEach-Object { "--dart-define=$_" }

Write-Host "fvm flutter pub get..." -ForegroundColor DarkGray
fvm flutter pub get

$buildArgs = @("build")
if ($Target -eq "appbundle") {
    $buildArgs += "appbundle"
    $buildArgs += "--release"
    $buildArgs += "--target-platform"
    $buildArgs += $PhoneTargetPlatforms
} else {
    $buildArgs += "apk"
    $buildArgs += "--release"
    $buildArgs += "--target-platform"
    $buildArgs += $PhoneTargetPlatforms
    if ($SplitPerAbi) {
        $buildArgs += "--split-per-abi"
    }
}

$buildArgs += $defineArgs

if ($Target -eq "apk" -and -not $SplitPerAbi) {
    Write-Host "APK universel (32 + 64 bits ARM)..." -ForegroundColor DarkGray
} elseif ($Target -eq "apk") {
    Write-Host "APK separes par architecture (32 + 64 bits ARM)..." -ForegroundColor DarkGray
}

Write-Host "fvm flutter $($buildArgs -join ' ') ..." -ForegroundColor Cyan
& fvm flutter @buildArgs

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Build termine." -ForegroundColor Green
if ($Target -eq "apk") {
    if ($SplitPerAbi) {
        Write-Host ""
        Write-Host "APK par architecture : build\app\outputs\flutter-apk\" -ForegroundColor Green
        $splitApks = Get-ChildItem "build\app\outputs\flutter-apk\app-*-release.apk" -ErrorAction SilentlyContinue
        foreach ($apk in $splitApks) {
            $abis = (Get-ApkAbiFolders $apk.FullName) -join ", "
            $hint = switch -Regex ($apk.Name) {
                "armeabi-v7a" { "telephones 32 bits (anciens appareils)" }
                "arm64-v8a"   { "telephones 64 bits (majorite actuelle)" }
                default       { "autre architecture" }
            }
            Write-Host "  $($apk.FullName)" -ForegroundColor White
            Write-Host "    ABIs: $abis — $hint" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "Distribution : choisir l'APK correspondant au telephone, ou les deux si inconnu." -ForegroundColor Yellow
    } else {
        $apk = "build\app\outputs\flutter-apk\app-release.apk"
        $apkPath = (Resolve-Path $apk).Path
        $abis = (Get-ApkAbiFolders $apkPath) -join ", "
        Write-Host ""
        Write-Host "APK a distribuer : $apkPath" -ForegroundColor Green
        Write-Host "Architectures incluses : $abis" -ForegroundColor DarkGray
        Write-Host "Installe sur tous les telephones Android ARM (32 et 64 bits)." -ForegroundColor Yellow
    }
} else {
    $aab = "build\app\outputs\bundle\release\app-release.aab"
    Write-Host "AAB (Play Store) : $((Resolve-Path $aab).Path)" -ForegroundColor Green
    Write-Host "Le Play Store delivre automatiquement la bonne architecture par appareil." -ForegroundColor DarkGray
}

