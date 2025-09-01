
$sshPath = "$env:USERPROFILE\.ssh"

# Correct use of ${env:USERNAME} to avoid misinterpreting the colon
icacls "$sshPath\id_rsa" /inheritance:r /grant:r "${env:USERNAME}:(R)"
icacls "$sshPath\id_rsa.pub" /inheritance:r /grant:r "${env:USERNAME}:(R)"
icacls "$sshPath\config" /inheritance:r /grant:r "${env:USERNAME}:(R)"
