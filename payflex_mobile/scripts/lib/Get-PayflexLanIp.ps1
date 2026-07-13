function Get-PayflexLanIp {
    <#
    .SYNOPSIS
    Détecte l'IPv4 LAN du PC (Wi‑Fi ou Ethernet) pour joindre le backend depuis un téléphone.
    #>
    param(
        [string]$PreferredHost = $env:PAYFLEX_API_HOST
    )

    if ($PreferredHost -and $PreferredHost.Trim()) {
        return $PreferredHost.Trim()
    }

    $privatePattern = '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'

    $candidates = @()

    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Loopback|Virtual|Hyper-V|VMware|vEthernet|WSL|Tailscale|TAP|TUN' }

        foreach ($adapter in $adapters) {
            $addrs = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.IPAddress -match $privatePattern -and
                    $_.PrefixOrigin -ne 'WellKnown'
                }
            foreach ($addr in $addrs) {
                $score = 0
                if ($adapter.Name -match 'Wi-?Fi|WLAN|Wireless') { $score += 100 }
                if ($adapter.InterfaceDescription -match 'Wi-?Fi|WLAN|Wireless') { $score += 50 }
                if ($adapter.Name -match 'Ethernet|LAN') { $score += 20 }
                if ($addr.IPAddress -match '^192\.168\.') { $score += 10 }
                $candidates += [PSCustomObject]@{
                    IP = $addr.IPAddress
                    Score = $score
                    Adapter = $adapter.Name
                }
            }
        }
    } catch {
        # Get-NetAdapter indisponible sur certaines configs : repli ci-dessous.
    }

    if ($candidates.Count -eq 0) {
        $fallback = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -match $privatePattern } |
            Sort-Object { if ($_.IPAddress -match '^192\.168\.') { 0 } else { 1 } }, IPAddress |
            Select-Object -First 1
        if ($fallback) {
            return $fallback.IPAddress
        }
        return $null
    }

    $best = $candidates | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, 'IPAddress' | Select-Object -First 1
    Write-Host "IP LAN détectée : $($best.IP) ($($best.Adapter))" -ForegroundColor DarkGray
    return $best.IP
}
