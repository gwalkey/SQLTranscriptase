<#
.SYNOPSIS
    Runs all other Powershell ps1 scripts for the target server
	
.DESCRIPTION
    Runs all other Powershell ps1 scripts for the target server    
	
.EXAMPLE
    00_RunAllScripts.ps1 localhost
	
.EXAMPLE
    00_RunAllScripts.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
	
	
.LINK
	http://github.com/gwalkey

#>

[CmdletBinding()]
Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)


cls

# Load Common Modules and .NET Assemblies
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Init
cls
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host -f Yellow -b Black "00 - RunAllScripts"
$starttime = get-date

# Server connection check
$SQLCMD1 = "select serverproperty('productversion') as 'Version'"
try
{
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"        
        $myver = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop| select -ExpandProperty Version
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		$myver = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop | select -ExpandProperty Version
        $serverauth = "win"
    }

    if($myver -ne $null)
    {
        Write-Output ("SQL Version: {0}" -f $myver)
    }

}
catch
{
    Write-Host -f red "$SQLInstance appears offline."
    Set-Location $BaseFolder
	exit
}

set-location $BaseFolder

Invoke-Expression ".\01_Server_Appliance.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Credentials.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Databases.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Logins.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Resource_Governor.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Roles.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Settings.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Shares.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Storage.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\01_Server_Triggers.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\02_Linked_Servers.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\03_NET_Assemblies.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\04_Agent_Jobs.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\04_Agent_Alerts.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\04_Agent_Operators.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\04_Agent_Proxies.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\04_Agent_Schedules.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\05_DBMail_Accounts.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\05_DBMail_Profiles.ps1 $SQLInstance $myuser $mypass"
#Invoke-Expression ".\06_Query_Plan_Cache.ps1 $SQLInstance $myuser $mypass"
#Invoke-Expression ".\06_Top_25_Worst_Queries.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\07_Service_Creds.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\09_SSIS_Packages_from_MSDB.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\09_SSIS_Packages_from_SSISDB.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\10_SSAS_Objects.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\11_SSRS_Objects.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\12_Security_Audit.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\13_PKI.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\14_Service_Broker.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\15_Extended_Events.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\16_Audits.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\17_Managed_Backups.ps1 $SQLInstance $myuser $mypass"
# Invoke-Expression ".\21_Dac_Packages.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\22_Policy_Based_Mgmt.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\23_Database_Diagrams.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\24_Plan_Guides.ps1 $SQLInstance $myuser $mypass"
# Invoke-Expression ".\25_Vuln_Scanner.ps1 $SQLInstance $myuser $mypass"
# Invoke-Expression ".\30_DataBase_Objects.ps1 $SQLInstance $myuser $mypass"
# Invoke-Expression ".\31_DataBase_Export_Table_Data.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\32_Database_Recovery_Models.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\33_VLF_Count.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\34_User_Objects_in_Master.ps1 $SQLInstance $myuser $mypass"
Invoke-Expression ".\50_Security_Tree.ps1 $SQLInstance $myuser $mypass"


Write-Output "`r`n"
$ElapsedTime = ((get-date) - $startTime)
Write-Output ("$SQLInstance Elapsed time: {0:00}:{1:00}:{2:00}.{3:0000}" -f $ElapsedTime.Hours,$ElapsedTime.Minutes,$ElapsedTime.Seconds, $ElapsedTime.TotalMilliseconds)

[System.GC]::Collect() | Out-Null
[System.GC]::GetTotalMemory($true) | Out-Null 

set-location $BaseFolder
exit
