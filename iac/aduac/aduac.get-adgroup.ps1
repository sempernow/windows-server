# Print all groups
Write-Host "`nALL Groups" -ForegroundColor Yellow
Get-ADGroup -Filter *
# Print all groups of Groups/OU1
$groupScopes = "DomainLocal", "Global", "Universal"
$DN = "*OU=Groups,OU=OU1,DC=lime,DC=lan"
foreach ($scope in $groupScopes) {
    Write-Host "`nSCOPE : $scope" -ForegroundColor Yellow
    $groups = Get-ADGroup -Filter "GroupScope -eq '$scope'" |
        Where-Object { $_.DistinguishedName -like "$DN" } |
        Select-Object Name, GroupCategory, ObjectClass, DistinguishedName
    $groups | Format-Table -AutoSize
}

exit 

# ...
# SCOPE : Global

# Name             GroupCategory ObjectClass DistinguishedName
# ----             ------------- ----------- -----------------
# ad-linux-users        Security group       CN=ad-linux-users,OU=Groups,OU=OU1,DC=lime,DC=lan
# ad-linux-sudoers      Security group       CN=ad-linux-sudoers,OU=Groups,OU=OU1,DC=lime,DC=lan
# ad-nfsanon            Security group       CN=ad-nfsanon,OU=Groups,OU=OU1,DC=lime,DC=lan
# ad-domain-users       Security group       CN=ad-domain-users,OU=Groups,OU=OU1,DC=lime,DC=lan