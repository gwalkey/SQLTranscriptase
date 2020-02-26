<#
.SYNOPSIS
    Gets the SQL Agent Database Mail Accounts
	
.DESCRIPTION
    Writes the SQL Agent Database Mail Accounts out to DBMail_Accounts.sql
	
.EXAMPLE
    05_DBMail_Accounts.ps1 localhost
	
.EXAMPLE
    05_DBMail_Accounts.ps1 server01 sa password
	
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
Write-Host  -f Yellow -b Black "05 - DBMail Accounts"
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



$fullfolderPath = "$BaseFolder\$sqlinstance\05 - DBMail Accounts"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


$sqlCMD2 = 
"
USE msdb
set nocount on;

create table #tbl (
id int not null,
[name] sysname not null,
[description] nvarchar(254) null,
email_address nvarchar(100) null,
display_name nvarchar(100) null,
replyto_address nvarchar(100) null,
servertype NVARCHAR(100) null,
servername NVARCHAR(100) NULL,
port NVARCHAR(100) NULL,
username NVARCHAR(100) NULL,
use_default_credentials NVARCHAR(100) NULL,
enable_ssl NVARCHAR(100) NULL
)

insert into #tbl
  EXEC msdb.dbo.sysmail_help_account_sp;

--SELECT * FROM #tbl
--DROP table #tbl;

DECLARE @mystring VARCHAR(max)

select 'USE msdb' + char(13) + char(10) + 'GO' +CHAR(13)+CHAR(10)+
'exec sysmail_add_account_sp '+
'@account_name = ' + quotename(#tbl.[name],CHAR(39)) + ', '+
'@description = '+ COALESCE(QUOTENAME(#tbl.[description],CHAR(39)),'null') + ', '+
'@email_address = ' + COALESCE(quotename(#tbl.email_address, char(39)),'NULL') + ', ' +
'@display_name = ' + QUOTENAME(#tbl.display_name,CHAR(39)) + ', ' + 
'@replyto_address = ' + QUOTENAME(#tbl.replyto_address,CHAR(39)) + ', ' +
'@mailserver_type = ' + QUOTENAME(#tbl.servertype,CHAR(39)) + ', '+
'@mailserver_name = ' + QUOTENAME(#tbl.servername,CHAR(39)) + ', '+
'@port = ' + QUOTENAME(#tbl.port,CHAR(39)) + ', '+
'@username = ' + coalesce(QUOTENAME(#tbl.username,CHAR(39)),'NULL')+ ', '+
'@use_default_credentials = ' + QUOTENAME(#tbl.use_default_credentials,CHAR(39)) +  ', '+
'@enable_ssl = ' + QUOTENAME(#tbl.enable_ssl,CHAR(39)) + CHAR(13) + char(10) + 'go' 
from #tbl order by id;

drop table #tbl;

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

if ($sqlresults -eq $null )
{
    Write-Output "No Database Mail Accounts found on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\05 - No Database Mail Accounts found.txt"
    Set-Location $BaseFolder
    exit
}


New-Item "$fullfolderPath\DBMail_Accounts.sql" -type file -force  |Out-Null
Foreach ($row in $sqlresults)
{
    $row.column1 | out-file "$fullfolderPath\DBMail_Accounts.sql" -Encoding ascii -Append
	Add-Content -Value "`r`n" -Path "$fullfolderPath\DBMail_Accounts.sql" -Encoding Ascii
}

Write-Output ("{0} DBMail Accounts Exported" -f @($sqlresults).count)


# Return To Base
set-location $BaseFolder



