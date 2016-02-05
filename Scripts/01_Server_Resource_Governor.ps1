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

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

#  Script Name
Write-Host  -f Yellow -b Black "01 - Server Resource Governor"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Resource_Governor.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO



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



# Set Local Vars
$server	= $SQLInstance

if ($serverauth -eq "win")
{
    $srv    = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
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

# Output Folder
Set-Location $BaseFolder
$output_path = "$BaseFolder\$SQLInstance\01 - Server Resource Governor\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

try
{
    # Pools
    $pools = $srv.ResourceGovernor.ResourcePools | where-object -FilterScript {$_.Name -notin "internal","default"}
    if ($pools.Count -gt 0)
    {
        #CopyObjectsToFiles $pools $output_path
        $pools.script() | out-file -FilePath "$output_path\pools.sql" -append -encoding ascii
    }

    # Workgroups
    foreach ($pool in $pools)
    {
        
        #Put Workgroups in parent pool's folder
        $pool_path = "$BaseFolder\$SQLInstance\01 - Server Resource Governor\"+$pool.Name+"\"
        if(!(test-path -path $pool_path))
            {
                mkdir $pool_path | Out-Null
            }
        
        #Workgroup
        $workloadgroups = $pool.WorkloadGroups
        foreach ($workloadgroup in $workloadgroups)
        {
            #CopyObjectsToFiles $workloadgroup $pool_path
            $myWLgroupFile = $pool_path+"\"+$workloadgroup.name+".sql"
            $workloadgroup.script() | out-file -FilePath  $myWLgroupFile -append -encoding ascii
        }
        
    } 
}
catch
{
    $fullfolderpath = "$BaseFolder\$SQLInstance\"
    echo null > "$fullfolderpath\01 - Server Resource Governor - not setup or enabled.txt"
}

# Return To Base
set-location $BaseFolder
