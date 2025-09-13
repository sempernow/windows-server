# IPv4 Forwarding Script – Client Edition

Write-Host "🌐 Enabling IPv4 Routing (Client Edition)..." -ForegroundColor Cyan

# 1. Persist system-level forwarding
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
$regName = "IPEnableRouter"
$regVal = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

if ($regVal.$regName -ne 1) {
    Write-Host "🔧 Setting registry key: IPEnableRouter = 1"
    Set-ItemProperty -Path $regPath -Name $regName -Value 1
} else {
    Write-Host "✅ Registry already set: IPEnableRouter = 1"
}

# 2. Enable interface-level forwarding on all vEthernet adapters
Write-Host "🔄 Enabling per-interface IPv4 forwarding..."
$ifaces = Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -like "vEthernet*" }

foreach ($iface in $ifaces) {
    Write-Host "➕ Enabling forwarding on $($iface.InterfaceAlias)"
    Set-NetIPInterface -InterfaceAlias $iface.InterfaceAlias `
                       -AddressFamily IPv4 `
                       -Forwarding Enabled -ErrorAction SilentlyContinue
}

# 3. Display final status
Write-Host "`n📋 Interface Forwarding Status:"
$ifaces = Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -like "vEthernet*" } |
    Select-Object InterfaceAlias, Forwarding, ConnectionState
$ifaces | Format-Table -AutoSize

Write-Host "`n✅ IPv4 forwarding is enabled for all vEthernet adapters." -ForegroundColor Green
