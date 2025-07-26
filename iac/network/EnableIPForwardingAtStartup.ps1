# TaskScheduler : Persist Forwarding of IP Packets across subnets
# @ C:\HOME\.config\Win11-config-scripts\EnableIPForwardingAtStartup.ps1
# See Windows-Server project
Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like 'vEthernet (*' } | Set-NetIPInterface -Forwarding Enabled -Verbose
