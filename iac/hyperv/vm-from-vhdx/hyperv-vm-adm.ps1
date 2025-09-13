# Create a Hyper-V VM configured to pre-existing VHDX that has OS already installed.
# - Useful to recover from nothing but the VHDX.

$vmName     = "a0"
$switch     = "InternalSwitchNAT1"
$memory     = 1GB
$basePath   = "S:\Hyper-V"
$vhdxDir    = "$basePath\VHDXs"

# Ensure basePath exists
New-Item -ItemType Directory -Path "$basePath" -Force | Out-Null

# 1. Create a new empty VM shell 
# - All Hyper-V created objects are created under this, $basePath/$vmName,
#   except for VHDXs, which are located at their declared path (below).
New-VM -Name "$vmName" -Path "$basePath" -Generation 2 -MemoryStartupBytes $memory -SwitchName "$switch" -NoVHD 

# - Disable SecureBoot to allow for the world of OSs beyond those of Microsoft Corporation.
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

# - Declare boot order : 1st is disk
$bootDrive = Get-VMHardDiskDrive -VMName $vmName | Where-Object { $_.Path -match "${vmName}_" }
Set-VMFirmware -VMName $vmName -FirstBootDevice $bootDrive

# - Scale processors
Set-VMProcessor -VMName $vmName -Count 2
# - Resource control
#   -Count 2          # Total count
#   -Reserve          # percent guaranteed
#   -Maximum          # percent cap; limit without changing -Count
#   -RelativeWeight   # Scheduling priority vs other VMs (here it's on par with siblings)
Set-VMProcessor -VMName $vmName `
    -Count 2 `
    -Reserve 20 `
    -Maximum 100 `
    -RelativeWeight 100

# - Scale memory
# - Dynamic memory
Set-VMMemory -VMName $vmName `
    -DynamicMemoryEnabled $true `
    -StartupBytes 1GB `
    -MinimumBytes 1GB `
    -MaximumBytes 4GB
# - Static memory
#Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false -StartupBytes 4GB

# 2. Attach storage
# - The core OS disk
Add-VMHardDiskDrive -VMName "$vmName" -Path "$vhdxDir\${vmName}.vhdx"
# - Static (faster fsync) for etcd
#Add-VMHardDiskDrive -VMName "$vmName" -Path "$vhdxDir\${vmName}-nfs.vhdx"

# 3. Grant VM SID access to its VHDX folder (important!)
$vmId = (Get-VM -Name $vmName).Id  
$acct = "NT VIRTUAL MACHINE\$vmId"
icacls "$vhdxDir" /grant "${acct}:(OI)(CI)(F)" /T


