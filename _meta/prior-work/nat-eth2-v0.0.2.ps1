# Bind secondary NIC to a created secondary subnet (natNetName)
# Create a secondary subnet natCIDR with secondary NIC and routes attached,
# for management by Windows Server on a Hyper-V host,
# and use NAT network to connect secondary subnet to internet through primary NIC.

$dns1 = "8.8.8.8"
$dns2 = "8.8.4.4"

$natNetName = "NAT1"
$mask       = "24"
# @ WAN CIDR : 192.168.28.0/24
$natCIDR    = "192.168.11.0/$mask"
$gw         = "192.168.11.1"
$eth2Name   = "Eth2"
$eth2IP     = "192.168.11.2"
$eth2       = Get-NetAdapter -Name $eth2Name

$subnetCIDR = "10.0.0.0/24"

# Set static IP on $eth2 
New-NetIPAddress -InterfaceIndex $eth2.ifIndex -IPAddress $eth2IP -PrefixLength $mask -DefGateway $gw 
Set-DnsClientServerAddress -InterfaceIndex $eth2.ifIndex -ServerAddresses ($dns1, $dns2)  

# Create NAT network to allow WAN (internet) access on $eth2 through $eth1 or any other having WAN (via 0.0.0.0)
New-NetNat -Name $natNetName -InternalIPInterfaceAddressPrefix $natCIDR -GatewayIPAddress $gw -NatExternalIPAddress "0.0.0.0"

# Verify $eth2 
New-NetIPAddress -InterfaceAlias $eth2Name -IPAddress $eth2IP -PrefixLength $mask

## Set Define Persistent Routes for Future Management by Windows Server

# Add a static route for traffic destined for another subdomain/network
New-NetRoute -DestinationPrefix $subnetCIDR -InterfaceAlias $eth2Name -NextHop $gw

# If Windows Server DHCP/DNS services are expected to manage $eth2, set a route accordingly
New-NetRoute -DestinationPrefix $natCIDR -InterfaceAlias $eth2Name -NextHop $gw
