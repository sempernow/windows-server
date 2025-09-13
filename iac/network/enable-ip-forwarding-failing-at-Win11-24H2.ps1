# Enable IPv4 Forwarding for Windows Host acting as LAN Router
# For WSL <-> NAT <-> Hyper-V VM scenarios

Write-Warning "⚠️ Fails at Win11 24H2"

exit 

Write-Host "🌐 Enabling IPv4 Routing on Windows..." -ForegroundColor Cyan

# 1. Ensure system-level forwarding is set
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
$regName = "IPEnableRouter"
$regVal = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

if ($regVal.$regName -ne 1) {
    Write-Host "🔧 Setting registry key: IPEnableRouter = 1"
    Set-ItemProperty -Path $regPath -Name $regName -Value 1
} else {
    Write-Host "✅ Registry already set: IPEnableRouter = 1"
}

# 2. Import RemoteAccess module if available
try {
    Import-Module RemoteAccess -ErrorAction Stop
    Write-Host "📦 RemoteAccess module loaded"
} catch {
    Write-Warning "⚠️ RemoteAccess module not available. Ensure RSAT / RemoteAccess feature is installed."
    # dism /online /get-features | findstr /i remoteaccess
    Enable-WindowsOptionalFeature -Online -FeatureName RemoteAccess -All

    exit 1
}

# 3. Configure RRAS for LAN routing only
try {
    Write-Host "🛠 Configuring RRAS (Routing Only)..."
    Install-RemoteAccess -VpnType RoutingOnly -ErrorAction Stop
} catch {
    if ($_.Exception.Message -match "already installed") {
        Write-Host "ℹ️ RRAS already installed."
    } else {
        Write-Warning "❌ Failed to configure RRAS: $_"
        exit 1
    }
}

# 4. Start the service
try {
    Write-Host "▶️ Starting RemoteAccess service..."
    Start-Service RemoteAccess -ErrorAction Stop
    Write-Host "✅ RemoteAccess service is now running"
    Set-Service RemoteAccess -StartupType Automatic
} catch {
    Write-Warning "❌ Failed to start RemoteAccess service: $_"
    exit 1
}

# 5. Enable per-interface IPv4 forwarding
Write-Host "🔄 Enabling per-interface IPv4 forwarding on vEthernet interfaces..."
$ifaces = Get-NetIPInterface -AddressFamily IPv4 `
    | Where-Object { $_.InterfaceAlias -like "vEthernet*" }

foreach ($iface in $ifaces) {
    Set-NetIPInterface -InterfaceAlias $iface.InterfaceAlias -AddressFamily IPv4 -Forwarding Enabled -ErrorAction SilentlyContinue
}

# 6. Display final status
Write-Host "`n📋 Interface Forwarding Status:"
$ifaces = Get-NetIPInterface -AddressFamily IPv4 `
    | Where-Object { $_.InterfaceAlias -like "vEthernet*" } `
    | Select-Object InterfaceAlias, Forwarding, ConnectionState
$ifaces | Format-Table -AutoSize

Write-Host "`n✅ IPv4 forwarding is fully enabled and RRAS is active." -ForegroundColor Green
