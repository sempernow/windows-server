# wac-install.ps1
# Silent installation of Windows Admin Center on Windows Server 2019/2022/2025
# WS 2022+ has WAC as a Role, so may install from GUI.
msiexec /i WindowsAdminCenter.msi /qn /L*v log.txt SME_PORT=443 SSL_CERTIFICATE_OPTION=generate
