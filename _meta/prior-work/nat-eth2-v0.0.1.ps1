
# Define network interfaces (names may differ)
$Eth1 = "Ethernet 1"   # Adapter connected to DHCP (IP1)
$Eth2 = "Ethernet 2"   # Adapter for static IP (IP2)

# Step 1: Assign static IP address to Eth2
$staticIP = "192.168.50.2"
$subnetMask = "255.255.255.0"
$dnsServer = "192.168.50.1"  # DNS Server on Windows Server AD DS (adjust as needed)
$gateway = "192.168.50.1"    # Gateway for routing traffic, possibly the AD or router

# Set static IP on Eth2
New-NetIPAddress -InterfaceAlias $Eth2 -IPAddress $staticIP -PrefixLength 24 -DefGateway $gateway
Set-DnsClientServerAddress -InterfaceAlias $Eth2 -ServerAddresses $dnsServer

# Step 2: Set up NAT for routing traffic through Eth1 (the interface with dynamic IP)
$natName = "NAT_Eth2_to_Eth1"
$natSubnet = "192.168.50.0/24"  # The subnet that IP2 belongs to

# Check if a NAT already exists, if not, create it
$nat = Get-NetNat | Where-Object { $_.Name -eq $natName }
if (-not $nat) {
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $natSubnet -ExternalIPInterface $Eth1
} else {
    Write-Host "NAT '$natName' already exists."
}

# Step 3: Verify routing tables (optional) and ensure forwarding is enabled for the adapters
Get-NetIPConfiguration

# Ensure forwarding is enabled (if needed)
Set-NetIPInterface -InterfaceAlias $Eth2 -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias $Eth1 -Forwarding Enabled
