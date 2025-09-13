$dns1 = "8.8.8.8"
$dns2 = "8.8.4.4"

$natNetName = "NAT1"
$mask       = "24"
$natCIDR    = "192.168.11.0/$mask"
$gw         = "192.168.11.1"
$eth2Name   = "Eth2"
$eth2IP     = "192.168.11.2"
$eth2       = Get-NetAdapter -Name "$eth2Name"
$subnetCIDR = "10.0.0.0/24"
$eth2Alias  = "vEthernet (ExternalSwitchForEth2)"

# Disable DHCP if necessary
Remove-NetIPAddress -InterfaceIndex $eth2.ifIndex -AddressFamily IPv4 -Confirm:$false
Set-NetIPInterface -InterfaceIndex $eth2.ifIndex -Dhcp Disabled
Set-NetIPInterface -InterfaceIndex $eth2.ifIndex -AddressFamily IPv4 -Dhcp Disabled
Set-NetIPInterface -InterfaceIndex $eth2.ifIndex -AddressFamily IPv6 -Dhcp Disabled
Remove-NetIPAddress -IPAddress "169.254.154.38" -Confirm:$false

Get-NetIPInterface -InterfaceIndex $eth2.ifIndex | Select-Object InterfaceAlias, AddressFamily, Dhcp
# PS> Get-NetIPInterface -InterfaceIndex $eth2.ifIndex | Select-Object InterfaceAlias, AddressFamily, Dhcp

# InterfaceAlias AddressFamily     Dhcp
# -------------- -------------     ----
# Eth2                    IPv6 Disabled
# Eth2                    IPv4  Enabled

# Set static IP on $eth2
# https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress?view=windowsserver2022-ps
# FAILING : Eth2 is in Disconnected state because that phyical adapter has no ethernet cable attached, on purpose. This NAT is to make that connection by bridging to phy adapter Eth1 which has internet connectivity. Since Eth2 has no connection (Ethernet cable) it is in a Disconnected stat. That explains why this NAT setup fails. For NAT to function correctly, the internal interface (Eth2) needs to be in a Connected state for Windows to route traffic through it. Solution is to create a virtual network that connects Eth2 to a valid network interface in a connected state. See https://chatgpt.com/share/67277006-d59c-8009-a25d-bf6f6cae7aa9 
New-NetIPAddress -InterfaceIndex $eth2.ifIndex -IPAddress $eth2IP -PrefixLength $mask -DefGateway $gw
#New-NetIPAddress -InterfaceIndex $eth2.ifIndex -IPAddress $eth2IP -PrefixLength $mask -DefGateway $gw -AddressFamily IPv4

Set-DnsClientServerAddress -InterfaceIndex $eth2.ifIndex -ServerAddresses ($dns1, $dns2)

# Create NAT network
# New-NetNat -Name $natNetName -InternalIPInterfaceAddressPrefix $natCIDR -NatExternalIPAddress "0.0.0.0"
New-NetNat -Name $natNetName -InternalIPInterfaceAddressPrefix $natCIDR

# Add a static route if needed
New-NetRoute -DestinationPrefix $subnetCIDR -InterfaceAlias $eth2Name -NextHop $gw

# Verify

Get-NetIPInterface -InterfaceIndex $eth2.ifIndex
Get-DnsClientServerAddress -InterfaceIndex $eth2.ifIndex
Get-NetRoute -InterfaceIndex $eth2.ifIndex
Get-NetNat -Name $natNetName
Get-NetAdapter -Name $eth2Name

Get-NetIPAddress -InterfaceIndex $eth2.ifIndex
Get-NetIPAddress -InterfaceIndex $eth2.ifIndex | Select-Object IPAddress, AddressFamily, InterfaceAlias

