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


Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)


cls

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

$startTime = get-date

#  Script Name
Write-Host -f Yellow -b Black "00 - RunAllScripts"

# Server connection check
try
{
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"
		# .NET Method
		# Open connection and Execute sql against server
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;connect timeout=5;"
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = "select serverproperty('productversion')"
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		# .NET Method
		# Open connection and Execute sql against server using Windows Auth
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;connect timeout=5;"
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = "select serverproperty('productversion')"
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

        $serverauth = "win"
    }

    if($results -ne $null)
    {
        Write-Output ("SQL Version: {0}" -f $results.Column1)
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 	

}
catch
{
    Write-Host -f red "$SQLInstance appears offline - Try Windows Authorization."
    Set-Location $BaseFolder
	exit
}

set-location $BaseFolder

& .\01_Server_Appliance.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Credentials.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Logins.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Resource_Governor.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Roles.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Settings.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Shares.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Storage.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Triggers.ps1 $SQLInstance $myuser $mypass
& .\02_Linked_Servers.ps1 $SQLInstance $myuser $mypass
& .\03_NET_Assemblies.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Jobs.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Alerts.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Operators.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Proxies.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Schedules.ps1 $SQLInstance $myuser $mypass
& .\05_DBMail_Accounts.ps1 $SQLInstance $myuser $mypass
& .\05_DBMail_Profiles.ps1 $SQLInstance $myuser $mypass
& .\07_Service_Creds.ps1 $SQLInstance
& .\09_SSIS_Packages_from_MSDB.ps1 $SQLInstance $myuser $mypass
& .\09_SSIS_Packages_from_SSISDB.ps1 $SQLInstance $myuser $mypass
& .\10_SSAS_Objects.ps1 $SQLInstance $myuser $mypass
& .\11_SSRS_Objects.ps1 $SQLInstance $myuser $mypass
& .\12_Security_Audit.ps1 $SQLInstance $myuser $mypass
& .\13_PKI.ps1 $SQLInstance $myuser $mypass
& .\14_Service_Broker.ps1 $SQLInstance $myuser $mypass
& .\15_Extended_Events.ps1 $SQLInstance $myuser $mypass
& .\16_Audits.ps1 $SQLInstance $myuser $mypass
& .\17_Managed_Backups.ps1 $SQLInstance $myuser $mypass
# & .\18_Replication.ps1 $SQLInstance $myuser $mypass
# & .\19_AlwaysOn.ps1 $SQLInstance $myuser $mypass
# & .\21_Dac_Packages.ps1 $SQLInstance $myuser $mypass
& .\22_Policy_Based_Mgmt.ps1 $SQLInstance $myuser $mypass
& .\23_Database_Diagrams.ps1 $SQLInstance $myuser $mypass
& .\24_Plan_Guides.ps1 $SQLInstance $myuser $mypass
# & .\30_DataBase_Objects.ps1 $SQLInstance $myuser $mypass
& .\32_Database_Recovery_Models.ps1 $SQLInstance $myuser $mypass
& .\33_VLF_Count.ps1 $SQLInstance $myuser $mypass
& .\34_User_Objects_in_Master.ps1 $SQLInstance $myuser $mypass


Write-Output "`r`n"
$ElapsedTime = ((get-date) - $startTime)
Write-Output ("$SQLInstance Elapsed time: {0:00}:{1:00}:{2:00}.{3:0000}" -f $ElapsedTime.Hours,$ElapsedTime.Minutes,$ElapsedTime.Seconds, $ElapsedTime.TotalMilliseconds)


set-location $BaseFolder
exit
