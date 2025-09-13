
# Quick status of all volumes
Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus

exit 

chkdsk C: /f    # Scan and fix
chkdsk C: /r    # Scan, fix and locate bad sectors and recover data
chkdsk c:       # Read-only mode

# Schedule a scan/repair when the drive is in use.
Repair-Volume -DriveLetter C -OfflineScanAndFix

Repair-Volume -DriveLetter C -Scan      # Scan only
Repair-Volume -DriveLetter C -SpotFix   # Quick repair (might require reboot)

