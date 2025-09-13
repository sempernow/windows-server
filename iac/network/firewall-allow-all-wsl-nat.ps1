# Unused : WSL2-NAT subnets lack connectivity regardless of firewall.

. .\network-define.ps1 

# Create Inbound Rule
New-NetFirewallRule -DisplayName "Allow Inbound WSL2 to InternalSwitchNAT1" `
    -Direction Inbound `
    -Action Allow `
    -Protocol Any `
    -RemoteAddress $WslCIDR `
    -LocalAddress $NatCIDR  `
    -Profile Any

# Create Outbound Rule
New-NetFirewallRule -DisplayName "Allow Outbound InternalSwitchNAT1 to WSL2" `
    -Direction Outbound `
    -Action Allow `
    -Protocol Any `
    -RemoteAddress $NatCIDR `
    -LocalAddress $WslCIDR `
    -Profile Any
