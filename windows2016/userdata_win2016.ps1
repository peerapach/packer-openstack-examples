#ps1_sysnative

# Setup variables
$Username = "Administrator"
$Password = "ADMIN_PASSWORD"
$computers = $query.Name

function Time-Sync {
  W32tm /resync /force
}

function Set-FirewallOff {
  NETSH AdvFirewall SET AllProfiles STATE OFF
  Stop-Service MpsSvc ; Set-Service MpsSvc -StartupType Manual
}

# Reset Administrator password
Write-Output "Changing local administrator password on $computer"
$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }

if ($existing -eq $null) {
    Write-Error "User $Username does not exist"
    return
}

$existing.SetPassword($Password)
$existing.SetInfo()

# Enable Administrator
Write-Output "Enable local administrator on $computers"
net user Administrator /active:yes

# turn off PowerShell execution policy restrictions
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine

# Enable WinRM
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="0"}'
winrm set winrm/config '@{MaxTimeoutms="7200000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client '@{TrustedHosts="*"}'

net stop winrm
sc config winrm start=auto
net start winrm

# Update windows 
Start-Service MpsSvc
#Write-Output "Installing PSWindowsUpdate..."
Install-PackageProvider -Name NuGet -Force
Install-Module PSWindowsUpdate -Force -Confirm:$False

#Write-Output "Updating Windows..."
Get-WUInstall -MicrosoftUpdate -AcceptAll -AutoReboot
Install-WindowsUpdate -AcceptAll -MicrosoftUpdate -AutoReboot -Confirm:$False

# Post processes
Set-FirewallOff
Time-Sync

Restart-Computer