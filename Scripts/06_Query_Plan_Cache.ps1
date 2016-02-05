<#
.SYNOPSIS
    Gets the contents of the Query Plan Cache on the target server
	
.DESCRIPTION
   Writes the Contents of the Quey Plan Cache to the "06 - Query Plan Cache" folder
   AdHoc
   Prepared
   Stored Procedure
   Trigger
      
.EXAMPLE
    06_Query_Plan_Cache.ps1 localhost
	
.EXAMPLE
    06_Query_Plan_Cache.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	Query Plan XML data as .sqlplan files
	
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
Write-Host  -f Yellow -b Black "06 - Query Plan Cache"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow -b black "Usage: ./06_Query_Plan_Cache.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
$fullfolderPath = "$BaseFolder\$sqlinstance\06 - Query Plan Cache"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

$AdhocfolderPath = "$BaseFolder\$sqlinstance\06 - Query Plan Cache\Adhoc\"
if(!(test-path -path $AdhocfolderPath))
{
	mkdir $AdhocfolderPath | Out-Null
}
$PrepfolderPath = "$BaseFolder\$sqlinstance\06 - Query Plan Cache\Prepared\"
if(!(test-path -path $PrepfolderPath))
{
	mkdir $PrepfolderPath | Out-Null
}
$ProcfolderPath = "$BaseFolder\$sqlinstance\06 - Query Plan Cache\StoredProcedures\"
if(!(test-path -path $ProcfolderPath))
{
	mkdir $ProcfolderPath | Out-Null
}
$trgfolderPath = "$BaseFolder\$sqlinstance\06 - Query Plan Cache\Trigger\"
if(!(test-path -path $trgfolderPath))
{
	mkdir $trgfolderPath | Out-Null
}

# Get Query Plan Cache contents - could be LARGE
$sql = 
"
select 
	cp.objtype as 'objtype', 
	coalesce(OBJECT_NAME(st.objectid,st.dbid),'Null') as 'objectName',
	qp.query_plan,
	CONVERT(varchar(max),cp.plan_handle,2) as 'plan_handle'
from sys.dm_exec_cached_plans cp
cross apply sys.dm_exec_sql_text(cp.plan_handle) st
cross apply sys.dm_exec_query_plan(cp.plan_handle) qp
order by 1,2


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
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$results = $DataSet.Tables[0].Rows

}

# Write out rows
$RunTime = Get-date

# Output to file
foreach ($query in $results) {
    
    $myFixedFileName = $query.plan_handle

	$myObjtype=$query.objtype
	switch ($myObjtype) {
		"Adhoc" {
			$myoutputfile = $AdhocfolderPath+$myFixedFileName+".sqlplan"
            $myoutputstring = $query.query_plan
			$myoutputstring | out-file -FilePath $myoutputfile -width 5000000 -encoding ascii
		}
		
		"Prepared" {
			$myoutputfile = $PrepfolderPath+$myFixedFileName+".sqlplan"
            $myoutputstring = $query.query_plan
			$myoutputstring | out-file -FilePath $myoutputfile -width 5000000 -encoding ascii
		}
		
		"Proc" {
			$myoutputfile = $ProcfolderPath+$myFixedFileName+".sqlplan"
            $myoutputstring = $query.query_plan
			$myoutputstring | out-file -FilePath $myoutputfile -width 5000000 -encoding ascii
		}
		
		"Trigger" {
			$myoutputfile = $trgfolderPath+$myFixedFileName+".sqlplan"
            $myoutputstring = $query.query_plan
			$myoutputstring | out-file -FilePath $myoutputfile -width 5000000 -encoding ascii
		}
	}
	

}


# Return To Base
set-location $BaseFolder
