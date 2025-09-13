## Create a virtual Internal Switch having a NAT subnet (CIDR)
## to *isolate* Hyper-V VMs from External DNS/DHCP servers,
## yet allow for Internet access via its NAT gateway.
## This configuration allows a Windows Server host to function 
## as Domain Controller (DC), fully managing ADDS/DNS/DHCP/... for 
## all hosts (VMs) on that subnet, unlike a (simpler) bridge configuration.

if (-not "$NatAlias") { . .\network-define.ps1 }

## Create Hyper-V EXTERNAL Switch if not exist
if (-not (Get-VMSwitch -Name "$ExtSwName" -ErrorAction SilentlyContinue)) {I
    . .\network-define.ps1 
    New-VMSwitch -Name "$ExtSwName" -NetAdapterName "$ExtAdapterName" -AllowManagementOS $true
    Start-Sleep -Seconds 5
}

## ICreate Hyper-V INTERNAL Switch if not exist
if (-not (Get-VMSwitch -Name "$NatSwName" -ErrorAction SilentlyContinue)) {
    . .\network-define.ps1 
    New-VMSwitch -Name "$NatSwName" -SwitchType Internal # -Notes "Internal NAT Subnet"
    Start-Sleep -Seconds 5
}

## Add Virtural Adapter to External Switch, attached to Windows OS (rather than a VM).
# Add-VMNetworkAdapter -Name "$ExtSwName" -ManagementOS -SwitchName "$ExtSwName" 

## Rename Adapter
#Rename-NetAdapter -InterfaceAlias 'OldName' -NewName "NewName"

## Remove Adapter
#Remove-VMNetworkAdapter -ManagementOS -VMNetworkAdapterName 'NAME'
## - RHEL VM reporting only "lo" interface 
##   suggests it's not connected to any virtual switch.

## NAT Configuration: Create NAT network (if not exist) to allow hosts (VMs) on its internal subnet to access external network(s) via their interface(s), e.g., ExtAlias having internet (WAN) access. This is crucial for internet connectivity while keeping the NAT network isolated from external DHCP or DNS interference. E.g., that of downstream gateway router having the ISP (Comcast) as its WAN.
if (-not (Get-NetNat -Name "$NatName" -ErrorAction SilentlyContinue).Name) {
    New-NetNat -Name "$NatName" -InternalIPInterfaceAddressPrefix "$NatCIDR" 
    Start-Sleep -Seconds 5
}
Get-NetNat | Select-Object Name, InternalIPInterfaceAddressPrefix

## Unable to set both Internal and External CIDRs on the NAT. 
## This workaround adds routing to WSL subnet
Set-NetIPAddress -InterfaceAlias "$WslAlias" -IPAddress "$WslGateway" -PrefixLength 20

## Static IP Configuration: Assign *static* IP on vEth adapter of the NAT subnet, which implicitly sets that as (default) gateway address. Static IPs are essential here for a stable environment, especially when running services like AD DS, DNS, and DHCP on WinSrv2019 VM. This ensures that the server is reliably reachable at a consistent address by all client VMs.
if (-not (Get-NetIPAddress -InterfaceAlias "$NatAlias" -IPAddress $NatGateway -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -InterfaceAlias "$NatAlias" -IPAddress $NatGateway -PrefixLength $NatMask -DefaultGateway $NatGateway
    Start-Sleep -Seconds 2
}

if (-not (Get-NetIPAddress -InterfaceAlias $NatAlias -IPAddress $NatGateway -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -InterfaceAlias $NatAlias -IPAddress $NatGateway -PrefixLength $NatMask -DefaultGateway $NatGateway
    Start-Sleep -Seconds 2
}

## Enable IP packet forwarding across subnets (adapters) else NAT subnet has no connectivity.
## Packet forwarding does not persist : Altered on reboot and OpenVPN-TAP toggle/usage. 
if ((Get-NetConnectionProfile -InterfaceAlias $ExtAlias).NetworkCategory -ne "Private") {
    Set-NetConnectionProfile -InterfaceAlias "$ExtAlias" -NetworkCategory Private
    Write-Host "$ExtAlias : NetworkCategory set to 'Private'"
}
if ((Get-NetConnectionProfile -InterfaceAlias $NatAlias).NetworkCategory -ne "Private") {
    Set-NetConnectionProfile -InterfaceAlias "$NatAlias" -NetworkCategory Private
    Write-Host "$NatAlias : NetworkCategory set to 'Private'"
}
Set-NetIPInterface -InterfaceAlias "$ExtAlias" -AddressFamily IPv4 -Forwarding Enabled -Verbose
Set-NetIPInterface -InterfaceAlias "$WslAlias" -AddressFamily IPv4 -Forwarding Enabled -Verbose
Set-NetIPInterface -InterfaceAlias "$DefAlias" -AddressFamily IPv4 -Forwarding Enabled -Verbose
Set-NetIPInterface -InterfaceAlias "$NatAlias" -AddressFamily IPv4 -Forwarding Enabled -Verbose

## Else all at once if all named 'vEthernet (*' :
#Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like 'vEthernet (*' } | Set-NetIPInterface -Forwarding Enabled -Verbose

## Create/Verify TaskScheduler task to persist Forwarding
#. .\network-taskscheduler-enable-forwarding.ps1

## Add DNS 
if (-not "$NatDNS") { . .\network-dns.ps1 }

## Toggle interface to apply changes : Perhaps unnecessary 

# #Disable-NetAdapter -Name "$DefAlias" -Confirm:$false
# Disable-NetAdapter -IncludeHidden -Name "$WslAlias" -Confirm:$false
# Disable-NetAdapter -Name "$ExtAlias" -Confirm:$false
# Disable-NetAdapter -Name "$NatAlias" -Confirm:$false

# Start-Sleep -Seconds 3

# #Enable-NetAdapter -Name "$DefAlias" -Confirm:$false
# Enable-NetAdapter -IncludeHidden -Name "$WslAlias" -Confirm:$false
# Enable-NetAdapter -Name "$ExtAlias" -Confirm:$false
# Enable-NetAdapter -Name "$NatAlias" -Confirm:$false 

# Start-Sleep -Seconds 3

#Get-NetIPInterface |Select-Object 
. .\network-get.ps1 
