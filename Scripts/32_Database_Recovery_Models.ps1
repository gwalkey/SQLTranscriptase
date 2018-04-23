<#
.SYNOPSIS
    Gets the Tranaasaction Log Recovery Mode for all non-system databases
	
.DESCRIPTION
    Gets the Tranaasaction Log Recovery Mode for all non-system databases
   
.EXAMPLE
    25_Database_Recovery_Models.ps1 localhost
	
.EXAMPLE
    25_Database_Recovery_Models.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML Files
	
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
Write-Host  -f Yellow -b Black "32 - Database Recovery Models"
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


# New UP SQL SMO Object
if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
}


# Create output folder
$output_path = "$BaseFolder\$SQLInstance\32 - DB Recovery Models\"
if(!(test-path -path $output_path))
{
    mkdir $output_path | Out-Null
}

	
# Get Recovery Models
$sqlCMD1 = 
"
SELECT  @@SERVERNAME AS Server ,
        d.name AS DBName ,
		(select ROUND(SUM(size) * 8 / 1024, 0) from sys.master_files where database_id = d.database_id) as 'SizeMB',
        d.recovery_model_Desc AS RecoveryModel ,
        d.Compatibility_level AS CompatiblityLevel ,
        d.create_date ,
        d.state_desc
FROM    sys.databases d
where d.name not in ('master','tempdb','msdb','model','distribution')
ORDER BY 2;
"

if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1 -User $myuser -Password $mypass
}

$RunTime = Get-date

# Write out rows to CSV
$myoutputfile = $output_path+"Recovery_Models.csv"
$sqlresults1 | select Server, DBName, SizeMB, RecoveryModel, CompatibilityLevel, create_date, state_Desc | ConvertTo-csv| Set-Content $myoutputfile

# Use HTML Fragments for multiple tables and inline CSS
$head = "<style type='text/css'>"
$head+="
table
    {
        Margin: 0px 0px 0px 4px;
        Border: 1px solid rgb(190, 190, 190);
        Font-Family: Tahoma;
        Font-Size: 9pt;
        Background-Color: rgb(252, 252, 252);
    }
tr:hover td
    {
        Background-Color: rgb(150, 150, 220);
        Color: rgb(255, 255, 255);
    }
tr:nth-child(even)
    {
        Background-Color: rgb(242, 242, 242);
    }
th
    {
        Text-Align: Left;
        Color: rgb(150, 150, 220);
        Padding: 1px 4px 1px 4px;
    }
td
    {
        Vertical-Align: Top;
        Padding: 1px 4px 1px 4px;
    }
"
$head+="</style>"

$RunTime = Get-date

$myoutputfile3 = $output_path+"Recovery_Models.html"

$myHTML1 = $sqlresults1 | select Server, DBName, SizeMB, RecoveryModel, CompatibilityLevel, create_date, state_Desc | ConvertTo-Html  -fragment -as Table -PreContent "<h3>Database Recovery Models on $SQLInstance</h3>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Database Recovery Models"  -PostContent "<h3>Ran on : $RunTime</h3>" |Set-Content -Path $myoutputfile3

set-location $BaseFolder