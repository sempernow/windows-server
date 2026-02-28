## * Browsers (Chrome) having "Secure DNS" enabled bypassed local DNS,
##   and so fail by: DNS_PROBE_FINISHED_NXDOMAIN error. 
## * This script adds Group Policy to exempt certain domains from CRL checks.
##   to fix browser's CRYPT_E_REVOCATION_OFFLINE error:

# Run as Administrator
Write-Host "=== Configuring Chrome for Windows CA Certificate ===" -ForegroundColor Cyan

$policyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
New-Item -Path $policyPath -Force -ErrorAction SilentlyContinue | Out-Null

# 1. Use Windows certificate store (your CA is there)
Set-ItemProperty -Path $policyPath -Name "ChromeRootStoreEnabled" -Value 0 -Type DWord
Write-Host "✅ Using Windows certificate store" -ForegroundColor Green

# 2. Disable online revocation checks (critical for LDAP CRLs)
Set-ItemProperty -Path $policyPath -Name "EnableOnlineRevocationChecks" -Value 0 -Type DWord
Write-Host "✅ Disabled online revocation checks" -ForegroundColor Green

# 3. Disable CT enforcement for your domain
$ctExemptions = @(
    "e2e.kube.lime.lan",
    "*.kube.lime.lan",
    "kube.lime.lan"
)
Set-ItemProperty -Path $policyPath -Name "CertificateTransparencyEnforcementDisabledForUrls" -Value $ctExemptions -Type MultiString
Write-Host "✅ Disabled CT enforcement" -ForegroundColor Green

# 4. Allow insecure local connections (helps with internal)
Set-ItemProperty -Path $policyPath -Name "AllowInsecureLocalhost" -Value 1 -Type DWord
Write-Host "✅ Allowed insecure localhost" -ForegroundColor Green

# 5. Add to HTTP allowlist
$httpAllowlist = @(
    "e2e.kube.lime.lan"
)
Set-ItemProperty -Path $policyPath -Name "HttpAllowlist" -Value $httpAllowlist -Type MultiString
Write-Host "✅ Added to HTTP allowlist" -ForegroundColor Green

Write-Host "`n✅ All policies applied!" -ForegroundColor Green
Write-Host "⚠️  CRITICAL: You MUST:" -ForegroundColor Yellow
Write-Host "1. Close ALL Chrome windows" -ForegroundColor Yellow
Write-Host "2. Check Task Manager and kill all chrome.exe processes" -ForegroundColor Yellow
Write-Host "3. Reopen Chrome and visit:" -ForegroundColor Yellow
Write-Host "   https://e2e.kube.lime.lan/foo/hostname" -ForegroundColor Cyan