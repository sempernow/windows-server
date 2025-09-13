## Run this at WinSrv2019 (dc1.lime.lan) host if stuck in APIPA address (169.254.x.x) mode.
## Bootstraps with a proper configuration.

################################################################
## Check Windows Firewall
## - Want Allow all Hyper-V and diagnostics on Private network
################################################################

$NatAlias = (Get-NetIPInterface -AddressFamily IPv4 |
             Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } |
             Select-Object -ExpandProperty InterfaceAlias -First 1)

# Addresses must be in NAT1 subnet CIDR (See network-define.ps1)
$dcIP = "192.168.11.2"
$gw   = "192.168.11.1"

# Reset the Adapter
Remove-NetIPAddress -InterfaceAlias "$NatAlias" -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias "$NatAlias" `
                 -IPAddress $dcIP `
                 -PrefixLength 24 `
                 -DefaultGateway $gw

Set-DnsClientServerAddress -InterfaceAlias "$NatAlias" -ServerAddresses 127.0.0.1

