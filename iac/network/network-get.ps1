# Get adapter information
$adapters = Get-NetIPAddress -AddressFamily IPv4 `
| Where-Object { $_.IPAddress -ne "127.0.0.1" }

Write-Output $adapters | Select-Object InterfaceAlias, IPAddress, PrefixLength

. .\network-define.ps1

# Get Hyper-V VM Switches
Get-VMSwitch | Select-Object Name, SwitchType, DetAdapterInterfaceDescription

# Get vEthernet Adapters
Get-NetAdapter -IncludeHidden | Select-Object Name, InterfaceDescription, ifIndex `
| Where-Object { $_.Name -like "vEthernet*" }

# Get NAT subnet
Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix

# Get Routes
Get-NetRoute | Where-Object { `
        $_.DestinationPrefix -like "$DefNtwk.*" -or $_.NextHop -like "$DefNtwk.*"`
        -or $_.DestinationPrefix -like "$WslNtwk.*" -or $_.NextHop -like "$WslNtwk.*"`
        -or $_.DestinationPrefix -like "$ExtNtwk.*" -or $_.NextHop -like "$ExtNtwk.*"`
        -or $_.DestinationPrefix -like "$NatNtwk.*" -or $_.NextHop -like "$NatNtwk.*"`
} | Select-Object DestinationPrefix, NextHop, ifIndex

# This route statement prints *only* if entered directly at console. Invisible (line feed only) otherwise.
#route print -4 | Select-String "$DefNtwk\.0|$WslNtwk\.0|$ExtNtwk\.0|$NatNtwk\.0"

# Get DNS
Get-DnsClient | Select-Object InterfaceAlias, ConnectionSpecificSuffix
Get-DnsClientServerAddress `
| Select-Object InterfaceAlias, AddressFamily, ServerAddresses `
| Where-Object { $_.ServerAddresses -ne "" }

# Get vEthernet Interfaces
if ("$DefAlias") {
    Get-NetIPInterface | Where-Object { $_.InterfaceAlias -like 'vEthernet (*' } `
    | Where-Object { $_.AddressFamily -eq "IPv4" } `
    | Select-Object InterfaceAlias, AddressFamily, InterfaceMetric, Dhcp, Forwarding, ConnectionState `
    | Format-Table

    Get-NetIPAddress | Where-Object { $_.InterfaceAlias -like 'vEthernet (*' } `
    | Where-Object { $_.AddressFamily -eq "IPv4" } `
    | Select-Object InterfaceAlias, IPAddress, PrefixLength `
    | Format-Table
}

# Get-NetIPConfiguration