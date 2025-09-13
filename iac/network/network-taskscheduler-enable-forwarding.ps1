##########################
# UPDATE This is useless
##########################
# TaskScheduler task required because Forwarding does not persist. 
# Create TaskScheduler task
$Name       = "EnableIPForwardingAtStartup"
$ScriptPath = "C:\HOME\.config\Win11-config-scripts\$Name.ps1"
$Argument   = '-File "' + $ScriptPath + '"'
$Action     = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $Argument
$Trigger    = New-ScheduledTaskTrigger -AtStartup
$Principal  = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task (once)
if (-Not (Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -TaskName $Name -Action $Action -Trigger $Trigger -Principal $Principal
} else {
    Write-Host "Task '$Name' already exists."
}
# Verify task exists
Get-ScheduledTask -TaskName "$Name"
