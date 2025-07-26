# 2024-11-15
# Capture of current configuration.
# Failing at Hyper-V Windows Server DNS connectivity to WSL2 via NAT1. 
# https://chatgpt.com/share/67313840-6800-8009-9fca-fde64f9d3715 

# Define network adapter names
$internalSwitchName = "vEthernet (InternalSwitchNAT1)"
$externalSwitchName = "vEthernet (ExternalSwitchEth1)"

# Configure IP addresses for each adapter
$internalIP = "192.168.11.1"
$internalPrefixLength = 24

# Set IP address for Internal Switch
New-NetIPAddress -InterfaceAlias $internalSwitchName -IPAddress $internalIP -PrefixLength $internalPrefixLength -DefGateway $internalIP

# Configure DNS servers for each adapter
$internalDNSServers = @("192.168.11.1", "192.168.28.1")
$externalDNSServers = @("192.168.28.1", "8.8.8.8")

# Set DNS servers for Internal Switch
Set-DnsClientServerAddress -InterfaceAlias $internalSwitchName -ServerAddresses $internalDNSServers

# Set DNS servers for External Switch
Set-DnsClientServerAddress -InterfaceAlias $externalSwitchName -ServerAddresses $externalDNSServers

# Add static routes
# Route to 192.168.11.0/24 via 192.168.11.1
New-NetRoute -DestinationPrefix "192.168.11.0/24" -InterfaceAlias $internalSwitchName -NextHop $internalIP -RouteMetric 1

# Route to 192.168.28.0/24 via 192.168.28.1
New-NetRoute -DestinationPrefix "192.168.28.0/24" -InterfaceAlias $externalSwitchName -NextHop "192.168.28.1" -RouteMetric 1

# Toggle interface to apply changes
Disable-NetAdapter -Name "$internalSwitchName" -Confirm:$false
Disable-NetAdapter -Name "$externalSwitchName" -Confirm:$false
Enable-NetAdapter -Name "$internalSwitchName" -Confirm:$false
Enable-NetAdapter -Name "$externalSwitchName" -Confirm:$false
