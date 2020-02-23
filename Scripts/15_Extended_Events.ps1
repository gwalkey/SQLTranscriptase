<#
.SYNOPSIS
    Exports Extended Events Sessions to .SQL files

.DESCRIPTION
    Exports Extended Events Sessions to .SQL files
	
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

[CmdletBinding()]
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

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 not found')
}

try
{
    Import-Module ".\LoadSQLSmo.psm1"
}
catch
{
    Throw('LoadSQLSmo.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host -f Yellow -b Black "15 - Extended Events"
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


# SQL Version check
if ($ver -lt 11)
{
    Write-Output "Extended Events supported only on SQL Server 2012 or higher"
    exit
}

# Any to do?
$sqlCMD2 = 
" 
select [event_session_id],[name] from sys.server_event_sessions
"

if ($serverauth -eq "win")
{
	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}

if ($sqlresults2 -eq $null)
{
    Write-Output "No Extended Event Sessions found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\15 - No Extended Event Sessions found.txt"
    Set-Location $BaseFolder
    exit
}

# Create Output folder
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\15 - Extended Events"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# *Must Credit*
# Jonathan Kehayias for the following code, including the correct DLLs, 
# the sequence of things and the use of 'System.Data.SqlClient.SqlConnectionStringBuilder'
# https://www.sqlskills.com/blogs/jonathan/
# http://sqlperformance.com/author/jonathansqlskills-com
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

# SQL Connection
$sqlconn = New-Object System.Data.SqlClient.SqlConnection $conBuild.ConnectionString.ToString();

# SQL Store Connection
$Server = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection $sqlconn

# XE Session Store
$XEStore = New-Object Microsoft.SqlServer.Management.XEvent.XEStore $Server

foreach($XESession in $XEStore.Sessions)
{    
    Write-Output ("Scripting out {0}" -f $XESession.Name)

    $output_path = $fullfolderPath+"\"+$XESession.name+".sql"    
    try
    {
        $script = $XESession.ScriptCreate().GetScript()
    }
    catch
    {
        Write-Output('Error calling ScriptCreate.getScript on this Session')
        Write-Output('Error: {0}' -f $_.Exception.Message)
    }
    $script | out-file  $output_path -Force -encoding ascii
}

Write-Output ("{0} Extended Event Sessions Exported" -f @($XEStore.Sessions).Count)

# Return To Base
set-location $BaseFolder

