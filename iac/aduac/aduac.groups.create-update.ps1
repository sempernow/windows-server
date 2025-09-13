# Bulk AD group creation/update from CSV file with idempotent operations.
# Creates or updates multiple Active Directory groups from a CSV file.
# Each group is processed with proper existence checks and updates.

# Import AD module
if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: Failed to import ActiveDirectory module: $_" -ForegroundColor Red
        exit 1
    }
}

# CSV Configuration
$CsvPath = ".\aduac.groups.create-update.csv" 
$ReportPath = ".\GroupCreationReport_$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# Expected CSV columns (sample):
# GroupName,OUPath,Description,GroupScope,GroupCategory
# SalesTeam,"OU=Groups,OU=Sales,DC=lime,DC=lan","Sales Department",Global,Security
# ITAdmins,"OU=Groups,OU=IT,DC=lime,DC=lan","IT Administrators",Global,Security

# Validate CSV exists
if (-not (Test-Path $CsvPath)) {
    Write-Host "ERROR: CSV file not found at $CsvPath" -ForegroundColor Red
    exit 1
}

# Initialize results collection
$results = @()

# Process each group from CSV
$groups = Import-Csv -Path $CsvPath
$totalGroups = $groups.Count
$processed = 0

foreach ($group in $groups) {
    $processed++
    Write-Host "`nProcessing group $processed of $totalGroups : '$($group.GroupName)'" -ForegroundColor Cyan
    
    # Initialize result object
    $result = [PSCustomObject]@{
        GroupName      = $group.GroupName
        OUPath         = $group.OUPath
        Status         = $null
        ActionTaken    = $null
        Details        = $null
        DistinguishedName = $null
        Timestamp      = Get-Date
    }

    try {
        # Verify OU exists first
        try {
            $null = Get-ADOrganizationalUnit -Identity $group.OUPath -ErrorAction Stop
        }
        catch {
            $result.Status = "Error"
            $result.Details = "Target OU does not exist: '$($group.OUPath)'"
            $results += $result
            Write-Host "  $($result.Details)" -ForegroundColor Red
            continue
        }

        # Check if group exists
        try {
            $existingGroup = Get-ADGroup -Identity $group.GroupName -Properties Description, GroupScope, GroupCategory -ErrorAction Stop
            
            $result.DistinguishedName = $existingGroup.DistinguishedName
            Write-Host "  Group exists at '$($existingGroup.DistinguishedName)'" -ForegroundColor Yellow

            # Build update parameters
            $updateParams = @{}
            if ($existingGroup.Description -ne $group.Description) { $updateParams.Description = $group.Description }
            if ($existingGroup.GroupScope -ne $group.GroupScope) { $updateParams.GroupScope = $group.GroupScope }
            if ($existingGroup.GroupCategory -ne $group.GroupCategory) { $updateParams.GroupCategory = $group.GroupCategory }

            if ($updateParams.Count -gt 0) {
                Set-ADGroup -Identity $group.GroupName @updateParams
                $result.Status = "Success"
                $result.ActionTaken = "Updated"
                $result.Details = "Updated $($updateParams.Count) properties"
                Write-Host "  $($result.Details): $($updateParams.Keys -join ', ')" -ForegroundColor Cyan
            }
            else {
                $result.Status = "Success"
                $result.ActionTaken = "No changes needed"
                $result.Details = "All properties already matched"
                Write-Host "  $($result.Details)" -ForegroundColor Green
            }
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # Group doesn't exist - create it
            try {
                $newGroup = New-ADGroup -Name $group.GroupName `
                            -Path $group.OUPath `
                            -GroupScope $group.GroupScope `
                            -GroupCategory $group.GroupCategory `
                            -Description $group.Description `
                            -DisplayName $group.GroupName `
                            -SamAccountName $group.GroupName `
                            -PassThru
                
                $result.Status = "Success"
                $result.ActionTaken = "Created"
                $result.Details = "New group created"
                $result.DistinguishedName = $newGroup.DistinguishedName
                Write-Host "  Successfully created group in '$($group.OUPath)'" -ForegroundColor Green
            }
            catch {
                $result.Status = "Error"
                $result.ActionTaken = "Failed creation"
                $result.Details = "Create failed: $_"
                Write-Host "  $($result.Details)" -ForegroundColor Red
            }
        }
        catch {
            $result.Status = "Error"
            $result.ActionTaken = "Check failed"
            $result.Details = "Existence check error: $_"
            Write-Host "  $($result.Details)" -ForegroundColor Red
        }
    }
    finally {
        $results += $result
    }
}

# Generate report
try {
    $results | Export-Csv -Path $ReportPath -NoTypeInformation -Force
    Write-Host "`nReport saved to '$ReportPath'" -ForegroundColor Magenta
}
catch {
    Write-Host "Warning: Could not save report: $_" -ForegroundColor Yellow
}

# Display summary
$successCount = ($results | Where-Object { $_.Status -eq "Success" }).Count
$errorCount = ($results | Where-Object { $_.Status -eq "Error" }).Count

Write-Host "`nProcessing Summary:" -ForegroundColor Magenta
Write-Host "  Total groups processed: $totalGroups"
Write-Host "  Successfully handled: $successCount" -ForegroundColor Green
Write-Host "  Errors encountered: $errorCount" -ForegroundColor ($errorCount -gt 0 ? "Red" : "Green")

# Return results for further processing if needed
$results
