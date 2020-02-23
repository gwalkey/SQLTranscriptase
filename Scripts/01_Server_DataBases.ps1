<#
.SYNOPSIS
    Creates HTML Table of basic Database details

.DESCRIPTION
    Creates HTML File in the "01 - Server DataBases" folder

.EXAMPLE
    01_Server_DataBases.ps1 localhost

.EXAMPLE
    01_Server_DataBases.ps1 localhost sa password

.Inputs
    ServerName\Instance, [User], [Password]

.Outputs
    HTML File

.NOTES
    
.LINK
    https://github.com/gwalkey
	
#>

[CmdletBinding()]
Param(
    [string]$SQLInstance = "localhost",
    [string]$myuser,
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
Write-Host  -f Yellow -b Black "01 - Server DataBases"

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




# HTML CSS
$head="
<style type='text/css'>
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
</style>"

$RunTime = Get-date

# Create Database Summary Listing
$sqlCMD2 = 
"
SELECT 
    DB_NAME(m.[database_id]) AS [Database_Name],
	d.create_date,
    CONVERT(float, m.size/128.0) AS [DBSizeMB],
	D.compatibility_level,
	case	
		when d.is_query_store_on=1 then 'On'
	else ''
	end as Query_Store,
	case
		when d.delayed_durability=0 then ''
		when d.delayed_durability=1 then 'Allowed'
		when d.delayed_durability=2 then 'Forced'
	end as 'Delayed_Durability',
	case	
		when d.is_read_committed_snapshot_on=1 then 'On'
		else ''
	end as 'RCSI',
	case
		when d.containment=0 then ''
		else 'On'
	end as 'Contained',
	case
		when d.is_auto_close_on=1 then 'On'
		else ''
	end as 'AutoClose',
	case
		when d.is_encrypted=1 then 'Yes'
		else ''
	end as 'Encrypted',
	d.log_reuse_wait_desc as 'LogReuse',
    m.state_desc as 'State',
	case when m.is_percent_growth=1 then '%' else 'MB' end as 'GrowthType',
	case when m.is_percent_growth=1 then growth else CONVERT(float, m.growth/128.0) end AS [GrowthIncr],
	case 
		when d.recovery_model=1 then 'Full'
		when d.recovery_model=2 then 'Bulk'
		when d.recovery_model=3 then 'Simple'
	end as 'Rec_Model',
	case	
		when d.is_published=1 then 'Yes'
		else ''
	end as 'REPL-Pub',
	case	
		when d.is_distributor=1 then 'Yes'
		else ''
	end as 'REPL-Dist',
	case
		when d.user_access=0 then 'Multi'
		when d.user_access=1 then 'Single'
		when d.user_access=2 then 'Restricted'
	end as 'Mode'
FROM 
	sys.master_files M WITH (NOLOCK)
inner join 
	sys.databases D
ON 
	M.database_id = D.database_id
where
	m.type_desc in ('ROWS','FILESTREAM')
ORDER BY 
	DB_NAME(m.[database_id]) 
OPTION (RECOMPILE);
"

if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}

$RunTime = Get-date
$FullFolderPath = "$BaseFolder\$SQLInstance\01 - Server DataBases\"
if(!(test-path -path $FullFolderPath))
{
    mkdir $FullFolderPath | Out-Null
}

$myoutputfile4 = $FullFolderPath+"\Database_Summary.html"
$myHtml1 = $sqlresults1 | select Database_Name, `
    create_date, `
    DBSizeMB, `
    compatibility_level, `
    Query_Store, `
    Delayed_Durability, `
    RCSI, `
    Contained, `
    AutoClose, `
    Encrypted, `
    LogReUse, `
    State, `
    GrowthType, `
    GrowthIncr, `
    Rec_Model, `
    REPL-Pub, `
    REPL-Dist, `
    Mode `
    | ConvertTo-Html -Fragment -as table -PreContent "<h1><mark>Database Summary</mark></H1><H2>Server: $SqlInstance</h2>"

    Convertto-Html -head $head -Body $myHtml1 -Title "Database Summary"  -PostContent "<h3>Ran on : $RunTime</h3>" `
    | Set-Content -Path $myoutputfile4 -Force

# Return To Base
set-location $BaseFolder
