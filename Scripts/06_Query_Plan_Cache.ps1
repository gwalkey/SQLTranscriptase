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
	Query Plan XML data as .sqlplan files for SSMS
	
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
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "06 - Query Plan Cache"
Write-Output("Server: [{0}]" -f $SQLInstance)

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

[int]$ver = GetSQLNumericalVersion $myver


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
$sqlCMD2 = 
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

# Write out rows
$RunTime = Get-date

# Output to file
foreach ($query in $sqlresults) {
    
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
