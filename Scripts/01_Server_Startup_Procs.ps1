<#
.SYNOPSIS
    Gets any Stored Procedures in the Master Database from the target server
    These procs automatially run when the Instance starts up
    SSIS_Cleanup and DQS install some startup procs here

.DESCRIPTION
	Writes out any Stored Procedure from Master into SQL files in the "01 - Server Startup Procs" folder

.EXAMPLE
    01_Server_Startup_Procs.ps1 localhost

.EXAMPLE
    01_Server_Startup_Procs.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "01 - Server Startup Stored Procedures"
Write-Output("Server: [{0}]" -f $SQLInstance)


function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"			
			$scripter.EnumScript($o)
		}
	}
}


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


# New Up SMO Object
if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($SQLInstance)
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

$db 	= New-Object ("Microsoft.SqlServer.Management.SMO.Database")
$tbl	= New-Object ("Microsoft.SqlServer.Management.SMO.Table")


# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	= $true;
$scripter.Options.ScriptData 	= $false;

# Add your favorite options from 
# https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.scriptingoptions.aspx
# https://www.simple-talk.com/sql/database-administration/automated-script-generation-with-powershell-and-smo/
$scripter.Options.AllowSystemObjects 	= $false
$scripter.Options.AnsiFile 				= $true
$scripter.Options.ClusteredIndexes 		= $true
$scripter.Options.DriAllKeys            = $true
$scripter.Options.DriForeignKeys        = $true
$scripter.Options.DriChecks             = $true
$scripter.Options.DriPrimaryKey         = $true
$scripter.Options.DriUniqueKeys         = $true
$scripter.Options.DriWithNoCheck        = $true
$scripter.Options.DriAllConstraints 	= $true
$scripter.Options.DriIndexes 			= $true
$scripter.Options.DriClustered 			= $true
$scripter.Options.DriNonClustered 		= $true
$scripter.Options.EnforceScriptingOptions 	= $true
$scripter.Options.ExtendedProperties    = $true
$scripter.Options.FullTextCatalogs      = $true
$scripter.Options.FullTextIndexes 		= $true
$scripter.Options.FullTextStopLists     = $true
$scripter.Options.IncludeFullTextCatalogRootPath= $true
$scripter.Options.IncludeHeaders        = $false
$scripter.Options.IncludeDatabaseRoleMemberships= $true
$scripter.Options.Indexes 				= $true
$scripter.Options.NoCommandTerminator 	= $false;
$scripter.Options.NonClusteredIndexes 	= $true
$scripter.Options.NoTablePartitioningSchemes = $false
$scripter.Options.Permissions 			= $true
$scripter.Options.SchemaQualify 		= $true
$scripter.Options.SchemaQualifyForeignKeysReferences = $true
$scripter.Options.ToFileOnly 			= $true
$scripter.Options.XmlIndexes            = $true

Write-Output "Starting Export..."

$sqlDatabase = $srv.Databases['Master']

# Script out objects for each DB
$db = $sqlDatabase
$fixedDBName = $db.name.replace('[','')
$fixedDBName = $fixedDBName.replace(']','')
$output_path = "$BaseFolder\$SQLInstance\01 - Server Startup Procs\"

# Stored Procs
Write-Output "$fixedDBName - Stored Procs"
$storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
CopyObjectsToFiles $storedProcs $output_path
Write-Output ("{0} Startup Stored Procs Exported" -f @($storedProcs).count)

# Return To Base
set-location $BaseFolder

