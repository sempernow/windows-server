# --- Hyper-V ghost cleanup: DRY-RUN by default ---
$WhatIf = $false #$true   # set $false to actually delete
$VerbosePreference = 'Continue'

function Assert-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    throw "Run PowerShell as Administrator."
  }
}
Assert-Admin

$pg      = Join-Path $env:ProgramData 'Microsoft\Windows\Hyper-V'
$vmRoot  = Join-Path $pg 'Virtual Machines'
$cacheA  = Join-Path $pg 'Virtual Machine Cache'
$cacheB  = Join-Path $pg 'Virtual Machines Cache'
$stateEx = '.vmrs','.vmgs','.bin'  # safe to delete state

Write-Verbose "Stopping VMMS..."
Stop-Service vmms -Force -ErrorAction SilentlyContinue

Write-Host "=== DRY-RUN mode: $WhatIf ==="
foreach($c in @($cacheA,$cacheB)){
  if(Test-Path $c){
    Write-Host "Cache folder present -> $c  (will delete)"
    Remove-Item $c -Recurse -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
  }
}

if(Test-Path $vmRoot){
  Get-ChildItem $vmRoot -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in $stateEx } |
    ForEach-Object{
      Write-Verbose "Removing stale state file: $($_.FullName)"
      Remove-Item $_.FullName -Force -WhatIf:$WhatIf -ErrorAction SilentlyContinue
    }
}

Write-Verbose "Starting VMMS..."
Start-Service vmms

Write-Host "`nDone. If ghosts still show in Hyper-V Manager, run again with `$WhatIf = `$false, then reopen the UI (or reboot once)."
