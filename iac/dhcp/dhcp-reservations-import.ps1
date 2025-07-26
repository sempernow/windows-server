# Create DHCP reservations for hosts using CSV file
# - Idempotent, so conflicts (host already has reserveration) 
#   are okay but spawn "Failed to ..." message per.
#
# - IT Industry v. Microsoft Corporation
#   MAC             v. ClientID
#   Subnet Zero     v. ScopeID
#   Hostname        v. Name
#   DHCP FQDN       v. ComputerName 

# Configuration
$csvPath = "$(Get-Location)\dhcp-reservations-export.csv"
$dcFQDN = "dc1.lime.lan"

# Import and process reservations
Import-Csv -Path $csvPath | ForEach-Object {
    # Build parameters
    $params = @{
        ScopeId      = $_.ScopeId
        IPAddress    = $_.IPAddress
        ClientId     = $_.ClientId
        Name         = if ($_.Name) { $_.Name } else { "" }  # Handle empty names
        Description  = if ($_.Description) { $_.Description } else { "" }
        ComputerName = $dcFQDN
    }
    
    # Sans error check ()
    #Add-DhcpServerv4Reservation @params

    # Check for existing reservation first (avoids some errors)
    $existing = Get-DhcpServerv4Reservation -ComputerName $dcFQDN -ScopeId $_.ScopeId -ClientId $_.ClientId -ErrorAction SilentlyContinue
    
    if ($existing) {
        Write-Warning "Skipped: $($_.IPAddress) ($($_.Name)) already exists in scope $($_.ScopeId)"
    }
    else {
        try {
            Add-DhcpServerv4Reservation @params -ErrorAction Stop
            Write-Host "[SUCCESS] Added: $($_.IPAddress) ($($_.Name))" -ForegroundColor Green
        }
        catch {
            Write-Warning "[FAILED] $($_.IPAddress): $_"
        }
    }
}

Write-Host "Import completed. Check warnings for skipped entries." -ForegroundColor Cyan