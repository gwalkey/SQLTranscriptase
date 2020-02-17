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
	https://github.com/gwalkey	
	
#>

[CmdletBinding()]
Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

# Load Common Modules and .NET Assemblies
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "04 - Agent Jobs"
Write-Output "Server $SQLInstance"

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

# Get Major Version Only
[int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

switch ($ver)
{
    7  {Write-Output "SQL Server 7"}
    8  {Write-Output "SQL Server 2000"}
    9  {Write-Output "SQL Server 2005"}
    10 {Write-Output "SQL Server 2008/R2"}
    11 {Write-Output "SQL Server 2012"}
    12 {Write-Output "SQL Server 2014"}
    13 {Write-Output "SQL Server 2016"}
    14 {Write-Output "SQL Server 2017"}
	15 {Write-Output "SQL Server 2019"}
}




# Check for Express version and exit - No Agent exists
$EditionSQL = "SELECT SERVERPROPERTY('Edition')"
# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $Edition = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}
else
{
try
    {
        $Edition = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

if ($Edition -ne $null )
{
    if ($edition.column1 -match "Express")
    {
        Write-Output ("Skipping '{0}'" -f $Edition.column1)
        exit
    }    
}


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

$ErrorActionPreference='Stop'
try
{
    $jobs = $server.JobServer.Jobs
}
catch
{
    Write-Output('Cant access the SMO Jobs Object')
    exit
}
$ErrorActionPreference='Continue'
 
# Create Output Folders
$fullfolderPathEn = "$BaseFolder\$sqlinstance\04 - Agent Jobs\Enabled"
if(!(test-path -path $fullfolderPathEn))
{
	mkdir $fullfolderPathEn | Out-Null
}

$fullfolderPathDis = "$BaseFolder\$sqlinstance\04 - Agent Jobs\Disabled"
if(!(test-path -path $fullfolderPathDis))
{
	mkdir $fullfolderPathDis | Out-Null
}

$jobcount = $server.JObserver.jobs.count
 
 # Export with filename fixups
 # Enabled Jobs First
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
        
        if ($job.Isenabled)
        {
            $FileName = "$fullfolderPathEn\$myjobname.sql"
        }
        else
        {
            $FileName = "$fullfolderPathDis\$myjobname.sql"
        }

        $job.Script() | Out-File -filepath $FileName
        $myjobname
    }

    Write-Output ("{0} Jobs Exported" -f $jobCount)
}
else
{
    Write-Output "No Agent Jobs Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Jobs Found.txt"
    Set-Location $BaseFolder
    exit
}

# Return To Base
Set-Location $BaseFolder
