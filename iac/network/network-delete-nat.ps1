
. .\network-define.ps1 

# Remove any existing NAT with the same name (force recreate if misconfigured)
$existingNat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
if ($existingNat) {
    Write-Host "⚠️ Existing NAT '$NatName' found. Removing it..."
    Remove-NetNat -Name $NatName -Confirm:$false
    Start-Sleep -Seconds 3
}
