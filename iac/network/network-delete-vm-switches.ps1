. .\network-define.ps1

# Before 
. .\network-get.ps1 

# Delete NAT rules associated with a specific name or subnet
Remove-NetNat -Name "$NatName" -Confirm:$false
#Remove-NetRoute -DestinationPrefix "$NatCIDR" -Confirm:$false
#Remove-NetRoute -DestinationPrefix "$NatGateway/32" -Confirm:$false
Remove-VMSwitch -Name "$NatSwName" -Confirm:$false
Remove-VMSwitch -Name "$ExtSwName" -Confirm:$false
Remove-VMSwitch -Name "$WslSwName" -Confirm:$false

# After
. .\network-get.ps1

