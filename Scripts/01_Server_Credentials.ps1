<#
.SYNOPSIS
    Gets the SQL Server Credentials on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "01 - Server Credentials" folder
   One file per Credential
   Credentials are used for PKI, TDE, Replication, Azure Connections, Remote Server connections for Agent Proxies or Database Synonyms   
   
.EXAMPLE
    01_Server_Credentials.ps1 localhost
	
.EXAMPLE
    01_Server_Credentials.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "01 - Server Credentials"
Write-Output("Server: [{0}]" -f $SQLInstance)

# Fix target servername if given a SQL named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]


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

# New up SMO Object
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


# Create Output Folder
Write-Output "$SQLInstance - Credentials"
$Credentials_path  = "$BaseFolder\$SQLInstance\01 - Server Credentials\"
if(!(test-path -path $Credentials_path))
{
    mkdir $Credentials_path | Out-Null	
}

# 2005 has different columns
if ($ver -eq 9)
{
    $mySQLquery = "
    USE master; 
    SELECT 
        credential_id, 
        name, 
        credential_identity, 
        create_date, 
        modify_date
    FROM
        sys.credentials
    order by 
        1
    "
}
else
{
    $mySQLquery = "
    USE master; 
    SELECT 
        credential_id, 
        name, 
        credential_identity, 
        create_date, 
        modify_date, 
        target_type, 
        target_id
    FROM
        sys.credentials
    order by 
        1
    "
}


# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQLquery -ErrorAction Stop
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
        $sqlresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQLquery -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

# Output to file
foreach ($Cred in $sqlresults)
{   $myFixedCredName = $Cred.name.replace('\','_')
	$myFixedCredName = $myFixedCredName.replace('/', '-')
	$myFixedCredName = $myFixedCredName.replace('[','(')
	$myFixedCredName = $myFixedCredName.replace(']',')')
	$myFixedCredName = $myFixedCredName.replace('&', '-')
	$myFixedCredName = $myFixedCredName.replace(':', '-')
    $myoutputfile = $Credentials_path+$myFixedCredName+".sql"
    $myoutputstring = "CREATE CREDENTIAL ["+$Cred.Name+"] WITH IDENTITY='"+$Cred.credential_identity+"'"
    $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
}


# Return to Base
set-location $BaseFolder

