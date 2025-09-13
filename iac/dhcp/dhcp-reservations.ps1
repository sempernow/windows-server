# Create DHCP reservations for hosts using CSV file
# - Idempotent, so conflicts (host already has reserveration) 
#   are okay but spawn "Failed to ..." message per.
#
# - IT Industry v. Microsoft Corporation
#   MAC             v. ClientID
#   Subnet Zero     v. ScopeID
#   Hostname        v. Name
#   DHCP FQDN       v. ComputerName 

$csvPath = "$(Get-Location)\dhcp-reservations.csv"
$dcFQDN = "dc1.lime.lan"

Import-Csv -Path $csvPath | ForEach-Object {
    $params = @{
        ScopeId      = $_.ScopeId
        Name         = $_.Name
        IPAddress    = $_.IPAddress
        ClientId     = $_.ClientId
        Description  = $_.Description
        ComputerName = $dcFQDN
    }

    Add-DhcpServerv4Reservation @params
}
