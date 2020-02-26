<#
.SYNOPSIS
    Gets the SQL Server Roles on the target server
	
.DESCRIPTION
   Writes the SQL Server Roles out to the "01 - Server Roles" folder
   
.EXAMPLE
    01_Server_Roles.ps1 localhost
	
.EXAMPLE
    01_Server_Roles.ps1 server01 sa password

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
Set-Location $BaseFolder
Write-Host  -f Yellow -b Black "01 - Server Roles"
Write-Output("Server: [{0}]" -f $SQLInstance)


# Server Connection Check
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


# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Roles"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Use TSQL, as SMO doesnt have Server Roles
$sqlCMD2 = 
"
with ServerPermsAndRoles as
(
    select
		'role membership' as security_type,
		spr.name as security_entity,
		sp.type_desc as principal_type,
		sp.type,
        sp.name as principal_name,        
        null as state_desc
    from sys.server_principals sp
    inner join sys.server_role_members srm
    on sp.principal_id = srm.member_principal_id
    inner join sys.server_principals spr
    on srm.role_principal_id = spr.principal_id
    where sp.type in ('s','u','r','g')
)
select 
    security_type,
    security_entity,
    principal_type,
    principal_name,
    state_desc 
from ServerPermsAndRoles
order by 1,2,3

"



# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
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
        $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

# Write out HTML summary
$RunTime = Get-date

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


$myoutputfile4 = $FullFolderPath+"\Server_Role_Members.html"
$myHtml1 = $sqlresults2 | select security_type, security_entity, principal_type, principal_name, state_desc | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Server Roles</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Server Roles"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

# Script out actual Server Role Create statements

$sqlCMD3 = 
"
SELECT  
'EXEC master..sp_addsrvrolemember @rolename = N''' + SR.name + ''', @loginame = N''' + SL.name + '''' 
FROM master.sys.server_role_members SRM
	JOIN master.sys.server_principals SR ON SR.principal_id = SRM.role_principal_id
	JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE SL.type IN ('S','G','U')
		AND SL.name NOT LIKE '##%##'
		AND SL.name NOT LIKE 'NT AUTHORITY%'
		AND SL.name NOT LIKE 'NT SERVICE%'
		AND SL.name <> ('sa')
ORDER by SR.Name, SL.Name;

"

if ($serverauth -eq "win")
{
    try
    {
        $sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -ErrorAction Stop
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
        $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

$myoutputfile5 = $FullFolderPath+"\Server_Role_Members.sql"

foreach($rolemember in $sqlresults3)
{
    $rolemember.Column1 | out-file $myoutputfile5 -append -encoding ascii
}


# Return To Base
set-location $BaseFolder
