# Create subnet for Hyper-V VMs that has internet accesss 
# via NAT subnet to isolate VM subnet from WAN-router's DNS/DHCP servers
# to allow for Windows Server to manage VM subnet's DNS/DHCP/...

$dns1 = "8.8.8.8"
$dns2 = "8.8.4.4"
$mask = 24

# vEthernet subnet
$SwitchName     = "InternalSwitch"
$vEthCIDR       = "192.168.100.0/$mask"   # Define the desired subnet and CIDR
$vEthGatewayIP  = "192.168.100.1"         # Gateway for internal switch

# NAT subnet (for external traffic)
$NatName        = "NAT1"
$NatCIDR        = "192.168.200.0/$mask"
$NatGatewayIP   = "192.168.200.1"

# Load module dependency
Import-Module Hyper-V

# Create Hyper-V Internal Switch
New-VMSwitch -Name "$SwitchName" -SwitchType Internal

# Wait a moment for the virtual switch interface to be created
Start-Sleep -Seconds 3

# Dynamically retrieve the vEthernet alias for the internal switch
$vEthAlias = (Get-NetAdapter | Where-Object { $_.Name -like "*$SwitchName*" }).Name

# Create virtual adapter and bind it to Internal Switch (set gateway IP on host vEthernet interface)
New-NetIPAddress -IPAddress $vEthGatewayIP -InterfaceAlias "$vEthAlias" -PrefixLength $mask

# Create NAT network to allow WAN (internet) access through any external interface
New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $vEthCIDR

# (Optional) to set up persistent routing for future subnets handled by the Windows Server:

# Route traffic between internal network and NAT subnet
# This route ensures traffic between the internal switch and the NAT network is forwarded correctly
New-NetRoute -DestinationPrefix $NatCIDR -InterfaceAlias $vEthAlias -NextHop $vEthGatewayIP
# ifIndex DestinationPrefix       NextHop                                  RouteMetric ifMetric PolicyStore
# ------- -----------------       -------                                  ----------- -------- -----------
# 53      192.168.200.0/24        192.168.100.1                                    256          Persiste...

# Windows Server DHCP/DNS services are expected to manage traffic for $vEthAlias
# Add a static route for traffic destined for another subdomain/network (if required)
New-NetRoute -DestinationPrefix $vEthCIDR -InterfaceAlias $vEthAlias -NextHop $NatGatewayIP
# ifIndex DestinationPrefix      NextHop                                  RouteMetric ifMetric PolicyStore
# ------- -----------------      -------                                  ----------- -------- -----------
# 53      192.168.100.0/24       192.168.200.1                                    256 15       ActiveStore
# 53      192.168.100.0/24       192.168.200.1                                    256          Persiste...


# Example of setting DNS client server address (on host)
# Set the DNS server for the host's vEthernet interface if needed (using internal or external DNS)
Set-DnsClientServerAddress -InterfaceAlias $vEthAlias -ServerAddresses ($dns1, $dns2)

# Until Windows Server or other provider/manager of DNS/DHCP is configured, 
# Windows host (Hyper-V) will report VM interface IP of "169.254.x.x"
# 
# The IP address 169.254.x.x is part of the APIPA (Automatic Private IP Addressing) range, 
# which Windows (and other operating systems) assigns when a device fails to get an IP address from a DHCP server. 
# If your Hyper-V VMs are reporting 169.254.x.x addresses, 
# it means they aren't successfully receiving an IP address from the DHCP server on the Windows Server, 
# and your RHEL VM reporting no network interface except lo likely indicates it's not connected to the virtual switch properly.