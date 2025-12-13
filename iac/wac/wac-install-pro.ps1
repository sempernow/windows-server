# wac-install-pro.ps1
# Silent installation of Windows Admin Center on Windows Server 2019/2022/2025
#Requires -RunAsAdministrator

# ----------------------- Configuration -----------------------
$MSIUrl      = "https://aka.ms/WACDownload"   # Always gets latest version
$MSIPath     = "$env:TEMP\WindowsAdminCenter.msi"
$LogPath     = "C:\WindowsAdminCenter-install.log"

# Change these only if you need something different
$Port        = 443
$CertOption  = "generate"   # "generate" or "installed"
# If you use an existing cert, uncomment and set the thumbprint:
# $CertThumbprint = "A1B2C3D4E5F6..."   
# $CertOption = "installed"

# -----------------------------------------------------------

Write-Host "Downloading latest Windows Admin Center..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $MSIUrl -OutFile $MSIPath -UseBasicParsing

Write-Host "Starting silent installation..." -ForegroundColor Cyan
$Arguments = @(
    "/i"
    "`"$MSIPath`""
    "/qn"
    "/L*v"
    "`"$LogPath`""
    "SME_PORT=$Port"
    "SSL_CERTIFICATE_OPTION=$CertOption"
)

if ($CertOption -eq "installed") {
    $Arguments += "SME_THUMBPRINT=$CertThumbprint"
}

Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -NoNewWindow

Write-Host "Installation finished. Log: $LogPath" -ForegroundColor Green
Write-Host "Access Windows Admin Center at: https://$(hostname):$Port" -ForegroundColor Yellow

# Optional: Open firewall port
if ($Port -eq 443) {
    $RuleName = "Windows Admin Center HTTPS 443"
} else {
    $RuleName = "Windows Admin Center HTTPS $Port"
}

if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
    Write-Host "Firewall rule created for port $Port" -ForegroundColor Green
}