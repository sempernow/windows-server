# Create a group in target OU : OU1/Groups 

# 1. Define 
$GroupName      = "ad-domain-users"
$OUPath         = "OU=Groups,OU=OU1,DC=lime,DC=lan" # Nested OUs
$Description    = "Domain Users"
$GroupScope     = "Global"      # DomainLocal|Global|Universal
$GroupCategory  = "Security"    # Security|Distribution

# 2. Create/Update
## Check if group already exists
try {
    $existingGroup = Get-ADGroup -Identity $GroupName -ErrorAction Stop
    Write-Host "Group '$GroupName' already exists at '$($existingGroup.DistinguishedName)'" -ForegroundColor Yellow
    
    ## Update (Any mismatching properties)
    if ($existingGroup.Description -ne $Description -or 
        $existingGroup.GroupScope -ne $GroupScope -or 
        $existingGroup.GroupCategory -ne $GroupCategory) {
        Set-ADGroup -Identity $GroupName `
                    -Description $Description `
                    -GroupScope $GroupScope `
                    -GroupCategory $GroupCategory
        Write-Host "Updated group properties for '$GroupName' :" -ForegroundColor Cyan
    }
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    ## Create if not yet exist
    try {
        New-ADGroup -Name $GroupName `
                    -Path $OUPath `
                    -GroupScope $GroupScope `
                    -GroupCategory $GroupCategory `
                    -Description "$Description" `
                    -DisplayName $GroupName `
                    -SamAccountName $GroupName `
                    -PassThru | Out-Null
        
        Write-Host "Successfully created group '$GroupName' in '$OUPath'" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create group '$GroupName': $_" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error checking for group existence: $_" -ForegroundColor Red
    exit 1
}

## Verify
$finalGroup = Get-ADGroup -Identity $GroupName -Properties Description, GroupScope, GroupCategory
$finalGroup | Select-Object Name, DistinguishedName, Description, GroupScope, GroupCategory | Format-List
