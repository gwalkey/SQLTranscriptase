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

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


Set-Location $BaseFolder

#  Script Name
Write-Host  -f Yellow -b Black "06 - Top 25 Worst Queries"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow -b black "Usage: ./06_Top_25_Worst_Queries.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


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


# Working
Write-Output "Server $SQLInstance"

# Create Output Folders
$fullfolderPath = "$BaseFolder\$sqlinstance\06 - Top 25 Worst Queries"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Get Em
$sql = 
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

# Run SQL
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using Sql Auth"
	# .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    $SqlAdapter.SelectCommand.CommandTimeout=300;
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
    $results = $DataSet.Tables[0].Rows

}
else
{
	Write-Output "Using Windows Auth"	
		
    # .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    $SqlAdapter.SelectCommand.CommandTimeout=300;
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$results = $DataSet.Tables[0].Rows

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
$myHtml1 = $results | `
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
