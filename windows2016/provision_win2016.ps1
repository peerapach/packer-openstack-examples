
$Computer = $query.Name

# Clear event logs
function Clear-All-Event-Logs ($ComputerName="localhost")
{
   $Logs = Get-EventLog -ComputerName $ComputerName -List | ForEach {$_.Log}
   $Logs | ForEach {Clear-EventLog -Comp $ComputerName -Log $_ }
   Get-EventLog -ComputerName $ComputerName -List
}
Clear-All-Event-Logs

# Remove and disable users
Write-Output "Disable and remove users"
Remove-LocalUser -name user1
Disable-LocalUser -name admin
Disable-LocalUser -name Administrator

# Reconfigure WinRM
Write-Output "Reconfigure WinRM"
winrm quickconfig -q
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config '@{MaxTimeoutms="60000"}'
winrm set winrm/config/client '@{TrustedHosts=""}'