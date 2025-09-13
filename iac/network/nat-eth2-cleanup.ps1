$eth2Name   = "Eth2"
$eth2       = Get-NetAdapter -Name "$eth2Name"

# Cleanup any prior attempt...

# Remove all IPv4 and IPv6 IP addresses assigned to the interface
Get-NetIPAddress -InterfaceIndex $eth2.ifIndex | Remove-NetIPAddress -Confirm:$false
# Remove all NAT networks
Get-NetNat | ForEach-Object { Remove-NetNat -Name $_.Name -Confirm:$false }
# Remove all routes linked to the interface
Get-NetRoute -InterfaceIndex $eth2.ifIndex | Remove-NetRoute -Confirm:$false
# Disable and enable the network adapter
Disable-NetAdapter -Name $eth2Name -Confirm:$false
Enable-NetAdapter -Name $eth2Name -Confirm:$false

# Verify that no IP address exists
Get-NetIPAddress -InterfaceIndex $eth2.ifIndex

# Verify that no routes exist for the interface
Get-NetRoute -InterfaceIndex $eth2.ifIndex
