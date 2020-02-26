<#
.SYNOPSIS
    Gets the SQL Agent Operators
	
.DESCRIPTION
    Writes the SQL Agent Operators out to Agent_Operators.sql
	
.EXAMPLE
    04_Agent_Operators.ps1 localhost
	
.EXAMPLE
    04_Agent_Operators.ps1 server01 sa password
	
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
Write-Host  -f Yellow -b Black "04 - Agent Operators"
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



$SQLCMD2 = 
"
USE msdb
set nocount on;

create table #tbl (
id int not null,
name sysname not null,
enabled tinyint not null,
email_address nvarchar(100) null,
last_email_date int not null,
last_email_time int not null,
pager_address nvarchar(100) null,
last_pager_date int not null,
last_pager_time int not null,
weekday_pager_start_time int not null,
weekday_pager_end_time int not null,
Saturday_pager_start_time int not null,
Saturday_pager_end_time int not null,
Sunday_pager_start_time int not null,
Sunday_pager_end_time int not null,
pager_days tinyint not null,
netsend_address nvarchar(100) null,
last_netsend_date int not null,
last_netsend_time int not null,
category_name sysname null);

insert into #tbl
  EXEC sp_help_operator; 


select 'USE msdb' + char(13) + char(10) + 'GO' +CHAR(13)+CHAR(10)+ 
'exec sp_add_operator ' + 
'@name = ' + quotename(name, char(39)) + ', ' + 
'@enabled = ' + cast (enabled as char(1)) + ', ' + 
'@email_address = ' + quotename(email_address, char(39)) + ', ' + 
case 
when pager_address is not null then '@pager_address = ' + quotename(pager_address, char(39)) + ', '
else ''
end + 
'@weekday_pager_start_time = ' + ltrim(str(weekday_pager_start_time)) + ', ' + 
'@weekday_pager_end_time = ' + ltrim(str(weekday_pager_end_time)) + ', ' +
'@Saturday_pager_start_time = ' + ltrim(str(Saturday_pager_start_time)) + ', ' +
'@Saturday_pager_end_time = ' + ltrim(str(Saturday_pager_end_time)) + ', ' +
'@Sunday_pager_start_time = ' + ltrim(str(Sunday_pager_start_time)) + ', ' +
'@Sunday_pager_end_time = ' + ltrim(str(Sunday_pager_end_time)) + ', ' +
'@pager_days = ' + cast(pager_days as varchar(3)) +  
case
when netsend_address is not null then ', @netsend_address = ' + quotename(netsend_address, char(39)) 
else ''
end + 
case 
when category_name != '[Uncategorized]' then ', @category_name = ' + category_name  
else '' 
end +
char(13) + char(10) + 'go' 
from #tbl order by id;

drop table #tbl;

"
# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -ErrorAction Stop
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
        $sqlresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

if ($sqlresults -eq $null )
{
    write-output "No Agent Operators Found on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Operators Found.txt"
    Set-Location $BaseFolder
    exit
}

$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Operators"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

New-Item "$fullfolderPath\Agent_Operators.sql" -type file -force  |Out-Null

[int]$countproperty = 0;
Foreach ($row in $sqlresults)
{
    $row.column1 | out-file "$fullfolderPath\Agent_Operators.sql" -Encoding ascii -Append
	Add-Content -Value "`r`n" -Path "$fullfolderPath\Agent_Operators.sql" -Encoding Ascii
    $countproperty = $countproperty +1;
}

Write-Output ("{0} Operators Exported" -f $countproperty)

# Return To Base
set-location $BaseFolder
