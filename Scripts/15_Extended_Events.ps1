<#
.SYNOPSIS
    Dumps the Extended Events Sessions to .SQL files

.DESCRIPTION
    Dumps the Extended Events Sessions to .SQL files
	
.EXAMPLE
    15_Extended_Events.ps1 localhost
	
.EXAMPLE
    15_Extended_Events.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
    .sql files
	
.NOTES

	
.LINK
	https://github.com/gwalkey
	
#>

Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance='localhost',

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,20)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,35)]
    [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

#  Script Name
Write-Host -f Yellow -b Black "15 - Extended Events"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./15_Extended_Events.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        $myver = $results.Column1

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
        $myver = $results.Column1

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


# SQL Version check
if (!($myver -like "11.0*") -and !($myver -like "12.0*") -and !($myver -like "13.0*"))
{
    Write-Output "Extended Events supported only on SQL Server 2012 or higher"
    exit
}

#  Any to do?
$sqlES = 
" 
select [event_session_id],[name] from sys.server_event_sessions
"

# Connect Correctly
if ($serverauth -eq "sql") 
{
	Write-Output "Using Sql Auth"	

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlES
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$EvtSessions = $DataSet.Tables[0].Rows

    if ($EvtSessions -eq $null)
    {
        Write-Output "No Extended Event Sessions found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\15 - No Extended Event Sessions found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 

    $serverauth="sql"
}
else
{
	Write-Output "Using Windows Auth"	

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    # .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlES
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$EvtSessions = $DataSet.Tables[0].Rows

    if ($EvtSessions -eq $null)
    {
        Write-Output "No Extended Event Sessions found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\15 - No Extended Event Sessions found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 
}

# Create Output folder
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\15 - Extended Events"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# *Must Credit*
# Jonathan Kehayias for the following code, including the correct DLLs, order of things and the use of 'System.Data.SqlClient.SqlConnectionStringBuilder'
# https://www.sqlskills.com/blogs/jonathan/
# http://sqlperformance.com/author/jonathansqlskills-com
# 
# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

$conBuild = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
$conBuild.psbase.DataSource = $SQLInstance
$conBuild.psbase.InitialCatalog = "master";

if ($serverauth -eq "win")
{
    $conBuild.psbase.IntegratedSecurity = $true;
}
else
{
    $conbuild.psbase.IntegratedSecurity = $false
    $conbuild.psbase.UserID = $myuser
    $conbuild.psbase.Password = $mypass
}

# Connect
$sqlconn = New-Object System.Data.SqlClient.SqlConnection $conBuild.ConnectionString.ToString();

# Server
$Server = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection $sqlconn

# XE Sessions
$XEStore = New-Object Microsoft.SqlServer.Management.XEvent.XEStore $Server

$ScrapSession = $XEStore.Sessions["system_health"];

foreach($XESession in $XEStore.Sessions)
{    
    Write-Output ("Scripting out {0}" -f $XESession.Name)

    $output_path = $fullfolderPath+"\"+$XESession.name+".sql"    
    
    $script = $XESession.ScriptCreate().GetScript()    
    $script | out-file  $output_path -Force -encoding ascii
}

Write-Output ("{0} Extended Event Sessions Exported" -f $XEStore.Sessions.Count)

# Return To Base
set-location $BaseFolder

