<#
.SYNOPSIS
    Gets the Top 25 Worst performing Queries on the target instance
	
.DESCRIPTION
   Gets the Top 25 Worst performing Queries on the target instance
      
.EXAMPLE
    06_Top_25_Worst_Queries.ps1 localhost
	
.EXAMPLE
    06_Top_25_Worst_Queries.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	Query Execution Data as HTML File
	
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
Write-Host  -f Yellow -b Black "06 - Top 25 Worst Queries"
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



# Create Output Folders
$fullfolderPath = "$BaseFolder\$sqlinstance\06 - Top 25 Worst Queries"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Get Em
$sqlCMD2 = 
"
use master;

SELECT top 25
db_name(qt.dbid) as 'DataBase',
SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.TEXT) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS 'Query',
qs.execution_count,
qs.total_worker_time,
qs.total_logical_reads, 
qs.total_logical_writes, 
qs.total_elapsed_time/1000000.0 total_elapsed_time_in_Sec,
qs.last_logical_reads,
qs.last_logical_writes,
qs.last_worker_time,
qs.last_elapsed_time/1000000.0 last_elapsed_time_in_Sec,
qs.last_execution_time
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
where qt.text not like '%INSERT%' and qt.text not like '%WAITFOR%'
and db_name(qt.dbid) is not null
ORDER BY 
11 desc, 6 desc

"

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
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
        $sqlresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}


# HTML CSS
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

$myoutputfile4 = $FullFolderPath+"\Top25_Worst_Queries.html"
$myHtml1 = $sqlresults | `
    select `
        Database, 
        Query, 
        execution_count, 
        total_worker_time, 
        total_logical_reads, 
        total_logical_writes,
        @{Name="total_elapsed_time_in_sec"; Expression={"{0:N6}" -f $_.total_elapsed_time_in_sec}},
        last_logical_reads,
        last_logical_writes,
        last_worker_time, 
        @{Name="last_elapsed_time_in_sec"; Expression={"{0:N6}" -f $_.last_elapsed_time_in_sec}},                   
        last_execution_time | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Top 25 Worst Queries</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Top 25 Worst Queries"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content "$fullfolderPath\Top25_Worst_Queries.html"


# Return To Base
set-location $BaseFolder
