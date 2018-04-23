<#
.SYNOPSIS
    Gets the Audits and Audit Specifications on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "16 - Audits" folder
   Saves the Server-level audits and specs as "Servername_ServerAudit_Auditname.sql" and the "ServerName_ServerAuditSpec_SpecName.sql"
   Saves the Database-level Audits and Specs into their own folder   
   
.EXAMPLE
    16_Audits.ps1 localhost
	
.EXAMPLE
    16_Audits.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    MSDN References:
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.audit.enumserverauditspecification.aspx
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.audit.enumdatabaseauditspecification.aspx

	
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
Write-Host  -f Yellow -b Black "16 - Audits"
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


# Create Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\16 - Audits"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}


# -----------------
# 1) Server Audits
# -----------------
foreach($Audit in $srv.Audits)
{
    # Script out objects for each DB
    $strmyauditName = $SQLInstance+"_ServerAudit_"+$audit.name+".sql"
    $strmyaudit = $Audit.script()
    $output_path = "$BaseFolder\$SQLInstance\16 - Audits\$strmyAuditName"
    Write-Output ("Server Audit: {0}" -f $audit.Name)
    $strmyaudit | out-file $output_path -Force -encoding ascii
}



# -------------------------------
# 2) Server Audit Specifications
# -------------------------------
foreach($Audit in $srv.ServerAuditSpecifications)
{
    # Script out objects for each DB
    $strmyauditName = $SQLInstance+"_ServerAuditSpec_"+$audit.name+".sql"
    $strmyaudit = $Audit.script()
    $output_path = "$BaseFolder\$SQLInstance\16 - Audits\$strmyAuditName"
    Write-Output ("Server Audit Spec: {0}" -f $audit.Name)
    $strmyaudit | out-file $output_path -Force -encoding ascii
}



# -------------------
# 3) Database Audits
# -------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    # Comment out if you want to include System Databases
    if ($sqlDatabase.Name -in ('Master','Model','MSDB','TempDB')) {continue}

    # Script out Audits per DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $DB_Audit_output_path = "$BaseFolder\$SQLInstance\16 - Audits\$fixedDBName"

    # Skip Offline Databases (SMO still enumerates them, but cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }
            
    foreach($DBAudit in $db.DatabaseAuditSpecifications)
    {
        # Script out objects for each DB
        $strmyauditName = $fixedDBName+"_DBAuditSpec.sql"
        $strmyaudit = $DBAudit.script()
        $output_path = $DB_Audit_output_path+"\"+$strmyAuditName
        if(!(test-path -path $DB_Audit_output_path))
            {
                mkdir $DB_Audit_output_path | Out-Null
            }

        Write-Output ("Database Audits for: {0}" -f $fixedDBName)
        $strmyaudit | out-file $output_path -Force -encoding ascii
    }

}


# Return To Base
set-location $BaseFolder

