$context = "dhcp-config"

# Define output directory (adjust as needed)
$backupDir = "$context-backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# Backup all DHCP scopes
Get-DhcpServerv4Scope | Export-Clixml -Path "$backupDir\Get-DhcpServerv4Scope.xml"

# Backup all reservations (for each scope)
Get-DhcpServerv4Scope | ForEach-Object {
    $scopeId = $_.ScopeId
    Get-DhcpServerv4Reservation -ScopeId $scopeId | Export-Clixml -Path "$backupDir\Get-DhcpServerv4Reservation.xml"
}

# Backup active leases (for each scope)
Get-DhcpServerv4Scope | ForEach-Object {
    $scopeId = $_.ScopeId
    Get-DhcpServerv4Lease -ScopeId $scopeId | Export-Clixml -Path "$backupDir\Get-DhcpServerv4Lease.xml"
}

# Backup server-level options (DNS, gateways, etc.)
Get-DhcpServerv4OptionValue | Export-Clixml -Path "$backupDir\Get-DhcpServerv4OptionValue.xml"

# Backup scope-specific options
Get-DhcpServerv4Scope | ForEach-Object {
    $scopeId = $_.ScopeId
    Get-DhcpServerv4OptionValue -ScopeId $scopeId | Export-Clixml -Path "$backupDir\Get-DhcpServerv4OptionValue-$($scopeId).xml"
}

# Generate summary log (PowerShell 5.1 compatible)
$scopeList = (Get-DhcpServerv4Scope | Select-Object -ExpandProperty ScopeId) -join ', '
$summary = @"
DHCP Backup Summary
------------------
Date: $(Get-Date)
Scopes: $scopeList
"@
$summary | Out-File -FilePath "$backupDir\Get-DhcpServerv4Scope.Summary.txt"

Get-DhcpServerv4Scope | ForEach-Object {
  Get-DhcpServerv4OptionValue -ScopeId $_.ScopeId
}| Out-File -FilePath "$backupDir\Get-DhcpServerv4Scope.Summary.txt" -Append

Write-Output "DHCP backup completed. Files saved to: $backupDir"