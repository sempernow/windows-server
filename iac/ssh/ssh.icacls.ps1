## Set ICACLS for, e.g., ssh u1@a0, to abide ~/.ssh/config

$sshDir = "$env:USERPROFILE\.ssh"

## Fix entire ~/.ssh directory
icacls $sshDir /inheritance:r
icacls $sshDir /grant:r "${env:USERNAME}:(F)"

## Fix files inside
Get-ChildItem $sshDir | ForEach-Object {
    icacls $_.FullName /inheritance:r
    icacls $_.FullName /grant:r "${env:USERNAME}:(F)"
}
