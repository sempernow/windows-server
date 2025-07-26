# Define output path
$outputPath = "dhcp-reservations-export.csv"

# Export all reservations to CSV
Get-DhcpServerv4Scope | ForEach-Object {
    Get-DhcpServerv4Reservation -ScopeId $_.ScopeId
} | Select-Object ScopeId, Name, IPAddress, ClientId, Description, Type | 
  Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

Write-Output "DHCP reservations exported to: $outputPath"