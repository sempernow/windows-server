# Hyper-V ghost cleanup (Saved-Critical stubs) - DRY RUN by default
# This does NOT touch any *.vhdx/*.avhdx on your separate disks.

$WhatIf = $true   # <-- set to $false to actually delete
$VerbosePreference = 'Continue'

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this PowerShell session as Administrator."
  }
}

Assert-Admin

# Ensure Hyper-V features & service
$vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
if (-not $vmms) {
  Write-Warning "Hyper-V VMMS service not found. Ensure Hyper-V role is installed."
  return
}

Write-Verbose "Stopping VMMS..."
Stop-Service vmms -Force -ErrorAction SilentlyContinue

$pg = Join-Path $env:ProgramData 'Microsoft\Windows\Hyper-V'
$targets = @(
  # Entire cache of runtime config
  (Join-Path $pg 'Virtual Machine Cache'),
  # Saved states & snapshot metadata (NOT disks)
  (Join-Path $pg 'Snapshots'),
  # Stale runtime/state files that can block deletion
  # We delete by extension under Virtual Machines safely
  (Join-Path $pg 'Virtual Machines')
)

# Show what we plan to touch
Write-Host "=== DRY RUN: $WhatIf ==="
Write-Host "ProgramData root: $pg"
$targets | ForEach-Object { Write-Host "Target: $_" }

# 1) Clear the cache folder entirely
$cache = Join-Path $pg 'Virtual Machine Cache'
if (Test-Path $cache) {
  Write-Verbose "Clearing Virtual Machine Cache ($cache)"
  Remove-Item $cache -Recurse -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
}

# 2) Remove saved-state/snapshot metadata
$snap = Join-Path $pg 'Snapshots'
if (Test-Path $snap) {
  Write-Verbose "Clearing Snapshots ($snap)"
  Remove-Item $snap -Recurse -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
}

# 3) Remove stale runtime/state files under Virtual Machines but NOT config dirs we still need
$vmRoot = Join-Path $pg 'Virtual Machines'
if (Test-Path $vmRoot) {
  Write-Verbose "Scanning Virtual Machines for *.vmrs/*.vmgs/*.bin"
  Get-ChildItem $vmRoot -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.vmrs','.vmgs','.bin' } |
    ForEach-Object {
      Write-Verbose "Removing state file: $($_.FullName)"
      Remove-Item $_.FullName -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
    }
}

# 4) Optional: scrub orphaned registry entries that reference missing config paths
#    We back up first.
$regRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization'
$backup = Join-Path $env:PUBLIC ("HyperV-Virtualization-backup-{0:yyyyMMdd-HHmmss}.reg" -f (Get-Date))
try {
  Write-Verbose "Exporting registry backup from '$regRoot' to '$backup'"
  & reg.exe export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization" "$backup" /y | Out-Null
} catch {
  Write-Warning "Could not export registry backup: $($_.Exception.Message)"
}

# Typical location for per-VM registrations:
$vmReg = Join-Path $regRoot 'VirtualMachines'
if (Test-Path $vmReg) {
  Write-Verbose "Checking registry VM entries under $vmReg"
  Get-ChildItem $vmReg -ErrorAction SilentlyContinue | ForEach-Object {
    $guidKey = $_.PsPath
    # Some builds store a ConfigLocation value; purge entries with missing config folders
    $cfg = (Get-ItemProperty -Path $guidKey -ErrorAction SilentlyContinue).ConfigurationLocation
    if ($cfg -and -not (Test-Path $cfg)) {
      Write-Verbose "Orphaned registry VM (missing config path): $guidKey  (ConfigLocation='$cfg')"
      # Remove the orphaned key
      Remove-Item -Path $guidKey -Recurse -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
    }
  }
} else {
  Write-Verbose "No per-VM registry hive found at $vmReg (may be fine on newer builds)."
}

Write-Verbose "Starting VMMS..."
Start-Service vmms

Write-Host "`n=== Done. Reopen Hyper-V Manager. If ghosts remain, set `$WhatIf = `$false and run again. ==="
