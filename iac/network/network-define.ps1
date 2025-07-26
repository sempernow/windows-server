# Load module dependency
Import-Module Hyper-V

# Must align with Get-NetRoute parameters : See network-get.ps1
$DefSwName = "Default Switch"
$WslSwName = "WSL (Hyper-V firewall)"
#$ExtSwName  = "ExternalSwitchEth1"  
$ExtSwName = "ExternalSwitchEth2"  
$NatSwName = "InternalSwitchNAT1"
$NatName = "NAT1"
$NatDomain = "lime.lan"
$dcFQDN = "dc1.$NatDomain"


# Dynamically Get InterfaceAlias by Switch Name
$DefAlias = (Get-NetAdapter -IncludeHidden | Where-Object { $_.Name -like "vEthernet *$DefSwName*" }).Name
$WslAlias = (Get-NetAdapter -IncludeHidden | Where-Object { $_.Name -like "vEthernet *$WslSwName*" }).Name
$ExtAlias = (Get-NetAdapter | Where-Object { $_.Name -like "vEthernet *$ExtSwName*" }).Name
$NatAlias = (Get-NetAdapter | Where-Object { $_.Name -like "vEthernet *$NatSwName*" }).Name

# Get interface IP and CIDR info side-by-side
$ipInfo = Get-NetIPAddress -AddressFamily IPv4 |
Where-Object { $_.InterfaceAlias -like 'vEthernet (*' } |
Select-Object InterfaceAlias, IPAddress, PrefixLength
$routeInfo = Get-NetRoute -AddressFamily IPv4 |
Where-Object { $_.DestinationPrefix -ne '0.0.0.0/0' -and $_.InterfaceAlias -like 'vEthernet (*' } |
Select-Object InterfaceAlias, DestinationPrefix
# Join them by InterfaceAlias
$joined = foreach ($ip in $ipInfo) {
    $routes = $routeInfo | Where-Object { $_.InterfaceAlias -eq $ip.InterfaceAlias }
    foreach ($r in $routes) {
        [PSCustomObject]@{
            InterfaceAlias    = $ip.InterfaceAlias
            IPAddress         = $ip.IPAddress
            PrefixLength      = $ip.PrefixLength
            DestinationPrefix = $r.DestinationPrefix
        }
    }
}
$filtered = (
    $joined | Where-Object { 
        $_.DestinationPrefix -notlike '*/32' -and 
        $_.DestinationPrefix -notlike '224.0.0.0/4'
    }
)
# InterfaceAlias                     IPAddress     PrefixLength DestinationPrefix
# --------------                     ---------     ------------ -----------------
# vEthernet (ExternalSwitchEth2)     192.168.28.47           24 192.168.28.0/24
# vEthernet (InternalSwitchNAT1)     192.168.11.1            24 192.168.11.0/24
# vEthernet (WSL (Hyper-V firewall)) 172.21.112.1            20 172.21.112.0/20
# vEthernet (Default Switch)         172.22.144.1            20 172.22.144.0/20

$ExtMask = ($filtered | Where-Object { $_.InterfaceAlias -like "$ExtAlias" }).PrefixLength
$DefMask = ($filtered | Where-Object { $_.InterfaceAlias -like "$DefAlias" }).PrefixLength
$WslMask = ($filtered | Where-Object { $_.InterfaceAlias -like "$WslAlias" }).PrefixLength
$NatMask = ($filtered | Where-Object { $_.InterfaceAlias -like "$NatAlias" }).PrefixLength

$ExtGateway = ($filtered | Where-Object { $_.InterfaceAlias -like "$ExtAlias" }).IPAddress
$DefGateway = ($filtered | Where-Object { $_.InterfaceAlias -like "$DefAlias" }).IPAddress
$WslGateway = ($filtered | Where-Object { $_.InterfaceAlias -like "$WslAlias" }).IPAddress
$NatGateway = ($filtered | Where-Object { $_.InterfaceAlias -like "$NatAlias" }).IPAddress

$ExtCIDR = ($filtered | Where-Object { $_.InterfaceAlias -like "$ExtAlias" }).DestinationPrefix
$DefCIDR = ($filtered | Where-Object { $_.InterfaceAlias -like "$DefAlias" }).DestinationPrefix
$WslCIDR = ($filtered | Where-Object { $_.InterfaceAlias -like "$WslAlias" }).DestinationPrefix
$NatCIDR = ($filtered | Where-Object { $_.InterfaceAlias -like "$NatAlias" }).DestinationPrefix

$ExtNtwk = ($ExtGateway -split '\.')[0..2] -join '.' 
$DefNtwk = ($DefGateway -split '\.')[0..2] -join '.' 
$WslNtwk = ($WslGateway -split '\.')[0..2] -join '.' 
$NatNtwk = ($NatGateway -split '\.')[0..2] -join '.' 

# Manual override : Set to IPv4 of Internet Gateway Router 
$ExtGateway = "$ExtNtwk.1"

# Dynamically Get the Default adapter
#$DefNtwk = Get-NetIPAddress -InterfaceAlias "$DefAlias" | Where-Object AddressFamily -eq "IPv4" | Select-Object -ExpandProperty IPAddress
#$DefNtwk = $DefNtwk -replace "\.\d+$", ""

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
