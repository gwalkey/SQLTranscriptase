<#
.SYNOPSIS
    Gets the SQL Server Resource Governor Pools and Workgroups on the target server
	
.DESCRIPTION
   Writes the SQL Server Roles out to the "01 - Resource Governor" folder
   One file for each Pool
   
.EXAMPLE
    01_Server_Resource_Governor.ps1 localhost
	
.EXAMPLE
    01_Server_Resource_Governor.ps1 server01 sa password

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
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "01 - Server Resource Governor"
Write-Output "Server $SQLInstance"


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




# New Up SMO Object
if ($serverauth -eq "win")
{
    $srv    = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
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


# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	        = $true;
$scripter.Options.ScriptData 	        = $false;

# Add your favorite options
# https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.scriptingoptions.aspx
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

# Create Output Folder
Set-Location $BaseFolder
$output_path = "$BaseFolder\$SQLInstance\01 - Server Resource Governor\"
if(!(test-path -path $output_path))
{
    mkdir $output_path | Out-Null
}

try
{
    # Get Pools
    $pools = $srv.ResourceGovernor.ResourcePools | where-object -FilterScript {$_.Name -notin "internal","default"}
    if ($pools.Count -gt 0)
    {
        $pools.script() | out-file -FilePath "$output_path\pools.sql" -append -encoding ascii
    }

    # Get Workgroups
    foreach ($pool in $pools)
    {
        
        # Put Workgroups in parent pool's folder
        $pool_path = "$BaseFolder\$SQLInstance\01 - Server Resource Governor\"+$pool.Name+"\"
        if(!(test-path -path $pool_path))
        {
            mkdir $pool_path | Out-Null
        }
        
        # Workgroup
        $workloadgroups = $pool.WorkloadGroups
        foreach ($workloadgroup in $workloadgroups)
        {
            $myWLgroupFile = $pool_path+"\"+$workloadgroup.name+".sql"
            $workloadgroup.script() | out-file -FilePath  $myWLgroupFile -append -encoding ascii
        }
        
    } 
}
catch
{
    $fullfolderpath = "$BaseFolder\$SQLInstance\"
    "Server Resource Governor is not setup or enabled" > "$fullfolderpath\01 - Server Resource Governor is not setup or enabled.txt"
}

# Return To Base
set-location $BaseFolder
