<#
.SYNOPSIS
    Gets the SQL Agent Jobs
	
.DESCRIPTION
   Writes the SQL Agent Jobs out to the "04 - Agent Jobs" folder
   One file per job 
   
.EXAMPLE
    04_Agent_Jobs.ps1 localhost
	
.EXAMPLE
    04_Agent_Jobs.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK

	
#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Script Name
Write-Host  -f Yellow -b Black "04 - Agent Jobs"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO



# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Jobs.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

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
		$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
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

		# SQLCMD.EXE Method
        #$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		# .NET Method
		# Open connection and Execute sql against server using Windows Auth
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
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

		# SQLCMD.EXE Method
    	#$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
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


# Check for Express version and exit - No Agent
# Turn off default error handler
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'	

$EditionSQL = "SELECT SERVERPROPERTY('Edition')"

if ($serverauth -eq "win")
{
    $Edition = Invoke-SqlCmd -query $EditionSQL -Server $SQLInstance
}
else
{
    $Edition = Invoke-SqlCmd -query $EditionSQL  -Server $SQLInstance –Username $myuser –Password $mypass    
}

if ($Edition -ne $null )
{
    if ($edition.column1 -match "Express")
    {
        Write-Output ("Skipping '{0}'" -f $Edition.column1)
        exit
    }    
}

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference 


# SMO Connection
$server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLInstance

# Using SQL Auth?
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1)
{
	$server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
	$server.ConnectionContext.Password=$mypass
	Write-Output "Using SQL Auth"
}
else
{
	Write-Output "Using Windows Auth"
}

$jobs = $server.JobServer.Jobs 
 
$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Jobs"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
 
 # Export with filename fixups
if ($jobs -ne $null)
{
    Write-Output "Exporting Agent Jobs:"

    ForEach ( $job in $jobs )
    {
        $myjobname = $job.Name
        $myjobname = $myjobname.Replace('\', '-')
        $myjobname = $myjobname.Replace('/', '-')
        $myjobname = $myjobname.Replace('&', '-')
        $myjobname = $myjobname.Replace(':', '-')
        $myjobname = $myjobname.replace('[','(')
        $myjobname = $myjobname.replace(']',')')
        
        $FileName = "$fullfolderPath\$myjobname.sql"
        $job.Script() | Out-File -filepath $FileName
        $myjobname
    }

    Write-Output ("{0} Jobs Exported" -f $jobs.count)
}
else
{
    Write-Output "No Agent Jobs Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Jobs Found.txt"
    Set-Location $BaseFolder
    exit
}


Set-Location $BaseFolder
