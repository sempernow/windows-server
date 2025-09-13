# Get adapter information

if (-not "$NatAlias") { . .\network-define.ps1 }

Write-Host "`n=== Declarations"

Write-Output "`
    ExtSwName  : $ExtSwName
    DefSwName  : $DefSwName
    WslSwName  : $WslSwName
    NatSwName  : $NatSwName

    ExtAlias   : $ExtAlias
    DefAlias   : $DefAlias
    WslAlias   : $WslAlias 
    NatAlias   : $NatAlias

    NatName    : $NatName  
    NatMask    : $NatMask  

    ExtNtwk    : $ExtNtwk  
    DefNtwk    : $DefNtwk  
    WslNtwk    : $WslNtwk  
    NatNtwk    : $NatNtwk  

    ExtCIDR    : $ExtCIDR  
    DefCIDR    : $DefCIDR  
    WslCIDR    : $WslCIDR  
    NatCIDR    : $NatCIDR  

    ExtGateway : $ExtGateway
    DefGateway : $DefGateway
    WslGateway : $WslGateway
    NatGateway : $NatGateway
"

Write-Host '=== Switches'

Get-VMSwitch `
    | Select-Object Name, SwitchType, DetAdapterInterfaceDescription `
    | Out-Host

Write-Host '=== Interfaces'

Get-NetAdapter -IncludeHidden `
    | Select-Object Name, InterfaceDescription, ifIndex `
    | Where-Object { $_.Name -like "vEthernet*" } `
    | Out-Host

# Write-Output $Adapters `
#     | Select-Object InterfaceAlias, IPAddress, PrefixLength `
#     | Out-Host

if ("$DefAlias") {
    Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like 'vEthernet (*' } `
    | Where-Object { $_.AddressFamily -eq "IPv4" } `
    | Select-Object InterfaceAlias, IPAddress, PrefixLength `
    | Out-Host
}

Write-Host '=== Routes'

Get-NetRoute | Where-Object { `
    $_.DestinationPrefix -like "$DefNtwk.*" -or $_.NextHop -like "$DefNtwk.*"`
    -or $_.DestinationPrefix -like "$WslNtwk.*" -or $_.NextHop -like "$WslNtwk.*"`
    -or $_.DestinationPrefix -like "$ExtNtwk.*" -or $_.NextHop -like "$ExtNtwk.*"`
    -or $_.DestinationPrefix -like "$NatNtwk.*" -or $_.NextHop -like "$NatNtwk.*"`
} | Select-Object DestinationPrefix, NextHop, ifIndex `
    | Out-Host

Write-Host "=== Route Table`n"

route print -4 `
    | Select-String "$DefNtwk\.0|$WslNtwk\.0|$ExtNtwk\.0|$NatNtwk\.0" `
    | ForEach-Object { $_.Line } `
    | Out-Host

Write-Host "`n=== NAT Subnet"

Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix `
    | Out-Host

Write-Host '=== DNS'

Get-DnsClient |
    Where-Object { $_.ConnectionSpecificSuffix -ne "" } |
    Select-Object InterfaceAlias, ConnectionSpecificSuffix |
    Out-Host

Get-DnsClientServerAddress |
    Where-Object {
        $_.AddressFamily -eq 2 -and
        $_.ServerAddresses -and
        $_.ServerAddresses.Count -gt 0
    } |
        Select-Object InterfaceAlias, InterfaceIndex, 
        @{Name="AddressFamily"; Expression={
            if ($_.AddressFamily -eq 2) { "IPv4" }
            elseif ($_.AddressFamily -eq 23) { "IPv6" }
            else { $_.AddressFamily }
        }},
        ServerAddresses |
    Out-Host

Write-Host '=== DHCP and Forwarding'

if ("$DefAlias") {
    Get-NetIPInterface | Where-Object { $_.InterfaceAlias -like 'vEthernet (*' } `
    | Where-Object { $_.AddressFamily -eq "IPv4" } `
    | Select-Object InterfaceAlias, AddressFamily, InterfaceMetric, Dhcp, Forwarding, ConnectionState `
    | Format-Table `
    | Out-Host
}


# Get-NetIPConfiguration