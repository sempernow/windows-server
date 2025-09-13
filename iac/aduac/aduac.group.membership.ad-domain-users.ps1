$sourceGroups = "ad-linux-users", "ad-linux-sudoers", "ad-nfsanon"
$targetGroup = "ad-domain-users"

foreach ($group in $sourceGroups) {
    try {
        # Check if the group is already a member
        $isMember = Get-ADGroupMember -Identity $targetGroup | 
                   Where-Object { $_.distinguishedName -eq (Get-ADGroup $group).distinguishedName }

        if (-not $isMember) {
            Add-ADGroupMember -Identity $targetGroup -Members $group
            Write-Host "Added group '$group' to '$targetGroup'" -ForegroundColor Green
        }
        else {
            Write-Host "'$group' is already a member of '$targetGroup'" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error processing '$group': $_" -ForegroundColor Red
    }
}