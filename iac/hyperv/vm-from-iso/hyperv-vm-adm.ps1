# --- Variables ---
$vmName    = "a0"
$switch    = "InternalSwitchNAT1"
$memory    = 1GB
$basePath  = "S:\Hyper-V"
$vhdxDir   = "$basePath\VHDXs"
$isoPath   = "S:\ISOs\rhel-9.4-x86_64-epel-registered.iso"
$osDisk    = "$vhdxDir\${vmName}.vhdx"
$osDiskSizeGB = 20GB  # Set to desired disk size

# --- Ensure paths exist ---
New-Item -ItemType Directory -Path "$basePath" -Force | Out-Null
New-Item -ItemType Directory -Path "$vhdxDir" -Force | Out-Null

# --- Create VM ---
New-VM -Name $vmName -Path $basePath -Generation 2 -MemoryStartupBytes $memory -SwitchName $switch -NoVHD

# --- Create empty VHDX for OS installation ---
New-VHD -Path $osDisk -SizeBytes $osDiskSizeGB -Dynamic
Add-VMHardDiskDrive -VMName $vmName -Path $osDisk

# --- Attach RHEL ISO as DVD ---
Add-VMDvdDrive -VMName $vmName -Path $isoPath

# --- Disable Secure Boot (not supported by default RHEL ISO bootloader) ---
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

# --- Set boot order: DVD first ---
$dvdDrive = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvdDrive

# --- Scale CPUs ---
Set-VMProcessor -VMName $vmName -Count 2 -Reserve 20 -Maximum 100 -RelativeWeight 100

# --- Enable Dynamic Memory ---
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -StartupBytes 1GB -MinimumBytes 1GB -MaximumBytes 4GB

# --- Grant NT VM access to VHDX folder (important) ---
$vmId = (Get-VM -Name $vmName).Id
$acct = "NT VIRTUAL MACHINE\$vmId"
icacls "$vhdxDir" /grant "${acct}:(OI)(CI)(F)" /T



