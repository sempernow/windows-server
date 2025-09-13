# Create a virtual Internal Switch having a NAT subnet (CIDR)
# to *isolate* Hyper-V VMs from External (host) DNS/DHCP servers,
# yet allow for Internet access via NAT gateway.
# This configuration allows Windows Server to fully manage DNS/DHCP/... 
# for all hosts (VMs) on that subnet, unlike a (simpler) bridge configuration.

. ./network-define.ps1 

# Create Hyper-V Internal Switch if not exist
if (-not (Get-VMSwitch -Name "$NatSwName" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "$NatSwName" -SwitchType Internal # -Notes "Internal NAT Subnet"
    Start-Sleep -Seconds 5
}

. ./network-define.ps1 

# Add External VMSwitch
#New-VMSwitch -Name "$ExtSwName" -NetAdapterName "vEthernet" -AllowManagementOS $true

# Add Virtural Adapter to External Switch, attached to Windows OS (rather than a VM).
#Add-VMNetworkAdapter -Name "$ExtSwName" -ManagementOS -SwitchName "$ExtSwName" 

# Rename Adapter
#Rename-NetAdapter -InterfaceAlias 'OldName' -NewName "NewName"

# Remove Adapter
#Remove-VMNetworkAdapter -ManagementOS -VMNetworkAdapterName 'NAME'
# - RHEL VM reporting only "lo" interface 
#   suggests it's not connected to any virtual switch.

# Create NAT network (if not exist) to allow hosts on its internal subnet 
# to access any external interface, e.g., Eth1 having WAN (internet) access.
if (-not (Get-NetNat -Name "$NatName" -ErrorAction SilentlyContinue)) {
    #New-NetNat -Name "$NatName" -ExternalIPInterfaceAddressPrefix "$WslCIDR" -InternalIPInterfaceAddressPrefix "$NatCIDR" 
    New-NetNat -Name "$NatName" -InternalIPInterfaceAddressPrefix "$NatCIDR" 
    Start-Sleep -Seconds 5
}
Get-NetNat |Select-Object Name,InternalIPInterfaceAddressPrefix

# Unable to set both Internal and External CIDRs on the NAT, 
# the workaround to add routing to WSL subnet
Set-NetIPAddress -InterfaceAlias "$WslAlias" -IPAddress "$WslGateway" -PrefixLength 20

# Assign *static* IP on vEth switch, which implicitly sets that as (default) gateway address
if (-not (Get-NetIPAddress -InterfaceAlias "$NatAlias" -IPAddress $NatGateway -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -InterfaceAlias "$NatAlias" -IPAddress $NatGateway -PrefixLength $NatMask -DefGateway $NatGateway
    Start-Sleep -Seconds 2
}

# Enable IP packet forwarding across subnets (adapters) else NAT subnet has no connectivity.
# Packet forwarding may not persist, e.g., OpenVPN TAP usage may alter routing and forwarding settings
Set-NetIPInterface -InterfaceAlias "$WslAlias" -Forwarding Enabled -Verbose
Set-NetIPInterface -InterfaceAlias "$DefAlias" -Forwarding Enabled -Verbose
Set-NetIPInterface -InterfaceAlias "$NatAlias" -Forwarding Enabled -Verbose
# Else all at once if all named 'vEthernet (*' :
#Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like 'vEthernet (*' } | Set-NetIPInterface -Forwarding Enabled -Verbose

Get-NetIPInterface |Select-Object 
# Add routes
#New-NetRoute -DestinationPrefix $ExtCIDR -NextHop $ExtGateway -InterfaceAlias "$ExtAlias"
#New-NetRoute -DestinationPrefix $WslCIDR -NextHop $WslGateway -InterfaceAlias "$WslAlias"
#New-NetRoute -DestinationPrefix $NatCIDR -NextHop $NatGateway -InterfaceAlias "$NatAlias"
# Bi-directionals?
#New-NetRoute -DestinationPrefix $WslCIDR -NextHop $WslGateway -InterfaceAlias "$WslAlias"

# Toggle interface to apply changes

#Disable-NetAdapter -Name "$DefAlias" -Confirm:$false
Disable-NetAdapter -IncludeHidden -Name "$WslAlias" -Confirm:$false
Disable-NetAdapter -Name "$ExtAlias" -Confirm:$false
Disable-NetAdapter -Name "$NatAlias" -Confirm:$false

Start-Sleep -Seconds 2

#Enable-NetAdapter -Name "$DefAlias" -Confirm:$false
Enable-NetAdapter -IncludeHidden -Name "$WslAlias" -Confirm:$false
Enable-NetAdapter -Name "$ExtAlias" -Confirm:$false
Enable-NetAdapter -Name "$NatAlias" -Confirm:$false

Start-Sleep -Seconds 2

. ./network-get.ps1 
