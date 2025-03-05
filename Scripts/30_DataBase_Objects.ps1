<#
.SYNOPSIS
    Gets the core Database Objects on the target server

.DESCRIPTION
    Writes the Objects out into subfolders in the "30 - DataBase Objects" folder
    Scripted Objects include:
    Database definition with Files and Filegroups
    DataBase Triggers
    Filegroups
    Full Text Catalogs
    Schemas
    Sequences
    Stored Procedures
    Synonyms
    Tables
    Table Triggers
    User Defined Functions
    User Defined Table Types
    Views
    Users



.EXAMPLE
    30_DataBase_Objects.ps1 localhost

.EXAMPLE
    30_DataBase_Objects.ps1 server01 sa password

.EXAMPLE
    30_Database_Objects.ps1 -SQLInstance localhost -myuser username -mypass password -myDatabase AdventureWorks2014 -myTable Person.Address

.Inputs
    ServerName, [SQLUser], [SQLPassword], [myDatabase]

.Outputs

.NOTES
    Use the -myDatabase parameter to just script out one database
    Use the -myTable parameter to just script out one table in the above Database

.LINK
    https://github.com/gwalkey

.Changelog
    GBW - March 5, 2025 - Added Partition Functions and Schemes
	
#>

[CmdletBinding()]
Param(
    [string]$SQLInstance,
    [string]$myuser,
    [string]$mypass,
    [string]$myDatabase,
    [string]$mytable

)

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 module not found in the current Folder')
}

# Load the Module
LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "30 - DataBase Objects"
Write-Host("Server: [{0}]" -f $SQLInstance)

# Parameter check: Table needs matching Database parameter
if ($myTable.Length -gt 0 -and $myDatabase.Length -eq 0)
{
    Write-Host ("Please specify the -MyDatabase parameter when using -myTable with {0}" -f $mytable)
    exit
}


# Server connection check
$SQLCMD1 = "select serverproperty('productversion') as 'Version'"
try
{
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Host "Testing SQL Auth"        
        $myver = ConnectSQLAuth `
            -SQLInstance $SQLInstance `
            -Database "master" `
            -SQLExec $SQLCMD1 `
            -User $myuser `
            -Password $mypass `
            -ErrorAction Stop | Select-Object -ExpandProperty Version

        $serverauth="sql"
    }
    else
    {
        Write-Host "Testing Windows Auth"
		$myver = ConnectWinAuth `
            -SQLInstance $SQLInstance `
            -Database "master" `
            -SQLExec $SQLCMD1 `
            -ErrorAction Stop | Select-Object -ExpandProperty Version

        $serverauth = "win"
    }

    if($null -ne $myver)
    {
        Write-Host ("SQL Version: {0}" -f $myver)
    }

}
catch
{
    Write-Host -f red "$SQLInstance appears offline."
    Set-Location $BaseFolder
	exit
}


function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | Out-Null
	}
	
	foreach ($o in $objects) { 
	
		if ($null -ne $o) {
			
			$schemaPrefix = ""
			
            try
            {
			    if ($null -ne $o.Schema -and $o.Schema -ne "") 
                {
    				$schemaPrefix = $o.Schema + "."
			    }
            }
            catch
            {
            }
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"
            try
            {                
                $urn = New-Object Microsoft.SQlserver.Management.sdk.sfc.urn($o.Urn);
                $scripter.Script($urn)
            }
            catch
            {
                $msg = "Cannot script this element:"+$o
                Write-Output $msg
            }
		}
	}
}


# New UP SQL SMO Object
if ($serverauth -eq "win")
{
    $srv        = New-Object ("Microsoft.SqlServer.Management.SMO.Server") ($SQLInstance)
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

# Find/Inspect other Server-Level Objects here
Write-Host "Looking for Objects..."

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

$RunTime = Get-date

# Create Database Summary Listing
$sqlCMD2 = 
"
SELECT 
    DB_NAME(m.[database_id]) AS [Database_Name],
    m.[file_id],
    m.name as 'Name',
    m.physical_name as 'FileName',
    m.type_desc as 'Type',
    m.state_desc as 'State',
	case when m.is_percent_growth=1 then '%' else 'MB' end as 'Growth',
	case when m.is_percent_growth=1 then growth else CONVERT(float, m.growth/128.0) end AS [Growth_in_MB],
    CONVERT(float, m.size/128.0) AS [DB_Size_in_MB],
	D.collation_name,
	D.compatibility_level
FROM sys.master_files M WITH (NOLOCK)
inner join sys.databases D
ON M.database_id = D.database_id
ORDER BY DB_NAME(m.[database_id]) OPTION (RECOMPILE);
"

if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}

$RunTime = Get-date
$FullFolderPath = "$BaseFolder\$SQLInstance\30 - DataBase Objects\"
if(!(test-path -path $FullFolderPath))
{
    mkdir $FullFolderPath | Out-Null
}

$myoutputfile4 = $FullFolderPath+"\Database_Summary.html"
$myHtml1 = $sqlresults1 | `Select-Object Database_Name,file_id, Name, FileName, Type, State, growth, growth_in_mb, DB_Size_in_MB | ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Database Summary</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Database Summary"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

# Create Database Object Reconstruction Order Hints File
"Database Object Reconstruction Order" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"`n " | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"01) Database itself with Filegroups and Files" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"02) .NET Assemblies" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"03) Linked Servers" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append    
"04) Logins" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append    
"05) Sequences" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"06) Synonyms" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"07) Schemas" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"08) Functions (Table-Valued and Scalar Functions)" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"09) User-Defined Table Types" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"10) Tables (with DRI Dependencies)" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"11) Views" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"12) Stored Procedures" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"13) Full-Text Catalogs" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"14) Table Triggers" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"15) Database Triggers" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"16) Partition Functions" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"17) Partition Schemes" | Out-File "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append

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
$scripter.Options.IncludeHeaders        = $true
$scripter.Options.IncludeDatabaseRoleMemberships= $true
$scripter.Options.IncludeDatabaseContext = $true;
$scripter.Options.Indexes 				= $true;

# https://connect.microsoft.com/SQLServer/feedback/details/790757/microsoft-sqlserver-management-smo-trasnfer-does-not-honor-scriptingoptions-nofilegroup-for-schema-transfer
# Closed as wont fix??
#$scripter.Options.NoFileGroup		    = $false;

$scripter.Options.NoCommandTerminator 	= $false;
$scripter.Options.NonClusteredIndexes 	= $true

$scripter.Options.NoTablePartitioningSchemes = $false

$scripter.Options.Permissions 			= $true

$scripter.Options.SchemaQualify 		= $true
$scripter.Options.SchemaQualifyForeignKeysReferences = $true

$scripter.Options.ToFileOnly 			= $true
$scripter.Options.Triggers              = $true

# WithDependencies creates one huge file for all tables in the order needed to maintain Referential Integrity - but REALLY HARD TO READ
$scripter.Options.WithDependencies		= $false # Leave OFF - creates issues - Jan 2016 we script out the DRI Table Order down below
$scripter.Options.XmlIndexes            = $true

# Set scripter options to ensure only schema is scripted
$scripter.Options.ScriptSchema 	= $true;
$scripter.Options.ScriptData 	= $false;

if ($myDatabase.Length -gt 0)
{
    Write-Host ("Only scripting Database {0}"-f $myDatabase)
}

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{
	# If only one database secified on the command-line, ignore/skip all others
	if ($myDatabase.Length -gt 0) 	
	{
		if ($sqlDatabase.Name -ne $myDatabase) {continue}		
	}

    # Skip System Databases
    if ($sqlDatabase.Name -in ('Model','MSDB','TempDB','SSISDB','distribution','Master')) {continue}

    # Skip Offline Databases (SMO still enumerates them, but cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Host ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\30 - DataBase Objects\$fixedDBname"

    # paths
    $DB_Path                     = "$output_path\"
    $Users_path 		         = "$output_path\Users\"
    $table_path 		         = "$output_path\Tables\"    
    $views_path 		         = "$output_path\Views\"
    $storedProcs_path 	         = "$output_path\StoredProcedures\"
    $udfs_path 			         = "$output_path\Functions\"
    $textCatalog_path 	         = "$output_path\FullTextCatalogs\"
    $udtts_path 		         = "$output_path\UserDefinedTableTypes\"
    $DBTriggers_path 	         = "$output_path\DBTriggers\"
    $Schemas_path                = "$output_path\Schemas\"
    $Filegroups_path             = "$output_path\Filegroups\"
    $Sequences_path              = "$output_path\Sequences\"
    $Synonyms_path               = "$output_path\Synonyms\"
    $DBScoped_Configs_path       = "$output_path\DBScopedConfigs\"
    $DBScoped_Creds_path         = "$output_path\DBScopedCredentials\"
    $QueryStore_path             = "$output_path\QueryStore\"
    $DBEDS_path                  = "$output_path\ExternalDataSources\"
    $DBExtFF_path                = "$output_path\ExternalFileFormats\"
    $DBSecPol_path               = "$output_path\SecurityPolicies\"
    $XMLSC_path                  = "$output_path\XMLSchemaCollections\"
    $DBColumnEncryptionKey_path  = "$output_path\ColumnEncryptionKeys\"
    $DBColumnMasterKey_path      = "$output_path\ColumnMasterKeys\"
    $DBRole_path                 = "$output_path\DBRoles\"
    $PartitionFunction_path      = "$output_path\PartitionFunctions\"
    $PartitionScheme_path        = "$output_path\PartitionSchemes\"
     

    # --------------------------------
    # Start Exporting Database Objects
    # --------------------------------

    # Main DB Export Folder
    if(!(Test-Path -path $DB_Path))
    {
        mkdir $DB_Path | Out-Null	
    }

    # Export Main Database Itself with Files and FileGroups
    Write-Host "$fixedDBName - Database"
    $MainDB = $db  | Where-Object  { -not $_.IsSystemObject  }
    $myoutputfile = $DB_Path + $fixedDBName + ".sql"
    $MainDB.Script() | Out-File -FilePath $myoutputfile -encoding ascii -Force

	# 2016+ Only Features
	if ([int]$($db.Version) -gt 852)
	{
		# Database Scoped Credentials
		Write-Host "$fixedDBName - Database Scoped Credentials"
		$DBScopedCreds = $db.DatabaseScopedCredentials 
		CopyObjectsToFiles $DBScopedCreds $DBScoped_Creds_path

        # Database Scoped Configs
        Write-Host "$fixedDBName - Database Scoped Configs"
        if(!(Test-Path -path $DBScoped_Configs_path))
		{
			mkdir $DBScoped_Configs_path | Out-Null	
		}
        $myDBScopedOutfile =$DBScoped_Configs_path+"\DBScopedConfigs.sql"
        "Use "+$DB.Name+"; `r`n" | Out-File -filepath $myDBScopedOutfile -encoding ascii -force
        "ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = "+$Db.Maxdop | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET MAXDOP = " +$db.MaxDopForSecondary | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION SET LEGACY_CARDINALITY_ESTIMATION = "+$db.LegacyCardinalityEstimation | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET LEGACY_CARDINALITY_ESTIMATION = "+$db.LegacyCardinalityEstimationForSecondary | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = "+$db.ParameterSniffing | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET PARAMETER_SNIFFING = "+$db.ParameterSniffingForSecondary | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = "+$db.QueryOptimizerHotfixes | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append
        "ALTER DATABASE SCOPED CONFIGURATION FOR SECONDARY SET QUERY_OPTIMIZER_HOTFIXES = "+$db.QueryOptimizerHotfixesForSecondary | Out-File -filepath $myDBScopedOutfile -encoding ascii -Append


		# QueryStore Options
		Write-Host "$fixedDBName - Query Store Options"
		$myoutputfile = $QueryStore_path + "Query_Store.sql"
		$QueryStore = $db.QueryStoreOptions 
		if ($null -ne $QueryStore)
		{
			if(!(test-path -path $QueryStore_path))
			{
				mkdir $QueryStore_path | Out-Null	
			}
			$QueryStore.Script() | Out-File -FilePath $myoutputfile -append -encoding ascii
		}
    
		# External Data Sources
		Write-Host "$fixedDBName - External Data Sources"
		$DB_EDS = $db.ExternalDataSources
		CopyObjectsToFiles $DB_EDS $DBEDS_path

		# External File Formats
		Write-Host "$fixedDBName - External File Formats"
		$DBExtFF = $db.ExternalFileFormats
		CopyObjectsToFiles $DBExtFF $DBExtFF_path

		# Security Policies
		Write-Host "$fixedDBName - Database Security Policies"
		$DBSecPol = $db.SecurityPolicies
		CopyObjectsToFiles $DBSecPol $DBSecPol_path

		# XMLSchema Collections
		Write-Host "$fixedDBName - XML Schema Collections"
		$DBXML_SC = $db.XmlSchemaCollections
		CopyObjectsToFiles $DBXML_SC $XMLSC_path

		# Always Encrypted Column Encryption Keys
		Write-Host "$fixedDBName - Column Encryption Keys"
		$DBAE_CEK = $db.ColumnEncryptionKeys
		CopyObjectsToFiles $DBAE_CEK $DBColumnEncryptionKey_path

		# Always Encrypted Column Master Keys
		Write-Host "$fixedDBName - Column Master Keys"
		$DBAE_CMK = $db.ColumnMasterKeys
		CopyObjectsToFiles $DBAE_CMK $DBColumnMasterKey_path

	}
        
    # Create Settings Path
    $DBSettingsPath = $output_path+"\Settings"

    if(!(Test-Path -path $DBSettingsPath))
    {
        mkdir $DBSettingsPath | Out-Null	
    }
   
       
    # Database Settings
    Write-Host "$fixedDBName - Settings"
    $mySettings = $db.Properties
    
    $myoutputfile4 = $DBSettingsPath+"\Database_Settings.html"
    $myHtml1 = $mySettings | Sort-Object Name | Select-Object Name, Value | ConvertTo-Html -Fragment -as table -PreContent "<h3>Database Settings for: $SQLInstance </h3>"
    ConvertTo-Html -head $head -Body "$myHtml1" -Title "Database Settings"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4
    
    # DBRoles
    Write-Host "$fixedDBName - Roles"

    # Create Output Sub Folder
    if(!(Test-Path -path $DBRole_path))
    {
        mkdir $DBRole_path | Out-Null	
    }

    # Get Role Properties and Members
    foreach ($role in $db.Roles)
    {
        # Create Role File
        $RoleFile = $DBRole_path+$role.name+".sql"
        $RoleName = $role.Name
        "Use "+$db.name | Out-File $RoleFile -Encoding ascii -Append
        "GO " | Out-File $RoleFile -Encoding ascii -Append
        " " | Out-File $RoleFile -Encoding ascii -Append
        "CREATE ROLE "+$RoleName | Out-File $RoleFile -Encoding ascii -Append
        " " | Out-File $RoleFile -Encoding ascii -Append

        foreach ($Roleproperty in $role.Properties)
        {
            "--- Role Property {0}={1}" -f $RoleProperty.name,$RoleProperty.value  | Out-File $RoleFile -Encoding ascii -Append
        }
        " " | Out-File $RoleFile -Encoding ascii -Append

        $RolePermissions = $role.EnumObjectPermissions()
        foreach ($RolePermission in $RolePermissions)
        {
            "Role Permission {0}={1}" -f $RoleProperty.name,$RoleProperty.value  | Out-File $RoleFile -Encoding ascii -Append
        }

        "---Members:" | Out-File $RoleFile -Encoding ascii -Append
        $members = $role.EnumMembers()
        
        foreach ($member in $members)
        {
            "EXEC sp_addrolemember '$RoleName','$member'"  | Out-File $RoleFile -Encoding ascii -Append
        }
    }

    # Tables
    Write-Host "$fixedDBName - Tables"

    if ($mytable.Length -gt 0 -and $myDatabase -eq $sqldatabase.name)
	{
        Write-Host ("Only for table {0}"-f $mytable)
        $tblSchema = ($mytable -split {$_ -eq "."})[0]
        $tblTable = ($mytable -split {$_ -eq "."})[1]
        $tbl = $db.Tables | Where-Object {$_.schema -eq $tblSchema -and $_.name -eq $tblTable}
	}
	else
	# Get all Tables
	{
		$tbl = $db.Tables  | Where-object  { -not $_.IsSystemObject  }
	}
    CopyObjectsToFiles $tbl $table_path

    # Stored Procs
    Write-Host "$fixedDBName - Stored Procs"
    $storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
    CopyObjectsToFiles $storedProcs $storedProcs_path

    # Users
    Write-Host "$fixedDBName - Users"
    $Users = $db.Users | Where-object { -not $_.IsSystemObject   } 
    CopyObjectsToFiles $Users $Users_path

    # Views
    Write-Host "$fixedDBName - Views"
    $views = $db.Views | Where-object { -not $_.IsSystemObject   } 
    CopyObjectsToFiles $views $views_path

    # UDFs
    Write-Host "$fixedDBName - Functions"
    $udfs = $db.UserDefinedFunctions | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $udfs $udfs_path

    # Table Types
    Write-Host "$fixedDBName - Table Types"
    $udtts = $db.UserDefinedTableTypes  
    CopyObjectsToFiles $udtts $udtts_path

    # FullTextCats
    Write-Host "$fixedDBName - FullTextCatalogs"
    $catalog = $db.FullTextCatalogs
    CopyObjectsToFiles $catalog $textCatalog_path

    # DB Triggers
    Write-Host "$fixedDBName - Database Triggers"
    $DBTriggers	= $db.Triggers
    CopyObjectsToFiles $DBTriggers $DBTriggers_path

    # Schemas
    Write-Host "$fixedDBName - Schemas"
    $Schemas = $db.Schemas | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $Schemas $Schemas_path

    # Sequences
    Write-Host "$fixedDBName - Sequences"
    $Sequences = $db.Sequences
    CopyObjectsToFiles $Sequences $Sequences_path

    # Synonyms
    Write-Host "$fixedDBName - Synonyms"
    $Synonyms = $db.Synonyms
    CopyObjectsToFiles $Synonyms $Synonyms_path

    # Partition Functions
    Write-Host "$fixedDBName - Partition Functions"
    $PartFunctions = $db.PartitionFunctions
    CopyObjectsToFiles $PartFunctions $PartitionFunction_path

    # Partition Schemes
    Write-Host "$fixedDBName - Partition Schemes"
    $PartSchemes = $db.PartitionSchemes
    CopyObjectsToFiles $PartSchemes $PartitionScheme_path

    # List Filegroups, Files and Path
    Write-Host "$fixedDBName - FileGroups"

    # Process FileGroups
    $myoutputfile = $Filegroups_path+"Filegroups.txt"
    if(!(Test-Path -path $Filegroups_path))
    {
        mkdir $Filegroups_path | Out-Null	
    }

    # Create Output File
    Out-File -filepath $myoutputfile -encoding ascii -Force
    Add-Content -path $myoutputfile -value "FileGroupName:          DatabaseFileName:           FilePath:"

    # Prep SQL for Filegroups
    $sqlCMD3 = "USE $db; SELECT `
    cast(sysFG.name as char(24)) AS FileGroupName,
    cast(dbfile.name as char(28)) AS DatabaseFileName,
    dbfile.physical_name AS DatabaseFilePath
    FROM
    sys.database_files AS dbfile
    INNER JOIN
    sys.filegroups AS sysFG
    ON
    dbfile.data_space_id = sysFG.data_space_id
    order by dbfile.file_id
    "

    # Run SQL
    if ($serverauth -eq "win")
    {
    	$sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3
    }
    else
    {
        $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -User $myuser -Password $mypass
    }

    # Script Out
    foreach ($FG in $sqlresults3)
    {
        $myoutputstring = $FG.FileGroupName+$FG.DatabaseFileName+$FG.DatabaseFilePath
        $myoutputstring | Out-File -FilePath $myoutputfile -append -encoding ascii -width 500
    }


    # Table Creation in Dependency Order to maintain DRI
    Write-Host "$fixedDBName - DRI Create Table Order"

    # Create Database Summary Listing
    $sqlCMD4 = 
    "
    use $fixedDBName;
    
    --- Reference/Credit:
    --- http://stackoverflow.com/questions/352176/sqlserver-how-to-sort-table-names-ordered-by-their-foreign-key-dependency
    ---
    declare @level int  -- Current depth
    declare @count int   
	   
    -- Table Variables
    declare @Tables TABLE (
	    [TableName] [nvarchar](257) NOT NULL,
	    [TableID] [int] NOT NULL,
	    [Ordinal] [int] NOT NULL
    )

    -- Step 1: Start with tables that have no FK dependencies
    insert into @Tables
    select s.name + '.' + t.name  as TableName
          ,t.object_id            as TableID
          ,0                      as Ordinal
      from sys.tables t
      join sys.schemas s
        on t.schema_id = s.schema_id
     where not exists
           (select 1
              from sys.foreign_keys f
             where f.parent_object_id = t.object_id)


    set @count = @@rowcount         
    set @level = 0


    -- Step 2: For a given depth this finds tables joined to 
    -- tables at this given depth.  A table can live at multiple 
    -- depths if it has more than one join path into it, so we 
    -- filter these out in step 3 at the end.
    --
    while @count > 0 begin

        insert @Tables (
               TableName
              ,TableID
              ,Ordinal
        ) 
        select s.name + '.' + t.name  as TableName
              ,t.object_id            as TableID
              ,@level + 1             as Ordinal
          from sys.tables t
          join sys.schemas s
            on s.schema_id = t.schema_id
         where exists
               (select 1
                  from sys.foreign_keys f
                  join @Tables tt
                    on f.referenced_object_id = tt.TableID
                   and tt.Ordinal = @level
                   and f.parent_object_id = t.object_id
                   and f.parent_object_id != f.referenced_object_id)
                       -- The last line ignores self-joins.  You'll
                       -- need to deal with these separately

       set @count = @@rowcount
       set @level = @level + 1
    end

    -- Step 3: This filters out the maximum depth an object occurs at
    -- and displays the deepest first.
    --
    select t.Ordinal
          --,t.TableID
          ,t.TableName
      from @Tables t
      join (select TableName     as TableName
                  ,Max (Ordinal) as Ordinal
              from @Tables
             group by TableName) tt
        on t.TableName = tt.TableName
       and t.Ordinal = tt.Ordinal
     order by t.Ordinal desc

 "

    # Run SQL
    if ($serverauth -eq "win")
    {
    	$sqlresults4 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4
    }
    else
    {
        $sqlresults4 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4 -User $myuser -Password $mypass
    }


    $RunTime = Get-Date
    $FullFolderPath = "$BaseFolder\$SQLInstance\30 - DataBase Objects\"
    if(!(test-path -path $FullFolderPath))
    {
        mkdir $FullFolderPath | Out-Null
    }
           
    
    "Create Your Tables in this order to maintain Declarative Referential Integrity`r`n" | Out-File "$output_path\DRI_Table_Creation_Order.txt" -Encoding ascii
    $sqlresults4 | Select-Object Ordinal, TableName | Out-File "$output_path\DRI_Table_Creation_Order.txt" -Encoding ascii -Append


    # -------------------------------------------------------------------------
    # Force GC
    # March 10, 2015 - can we manually kick off a GC pass?
    # Tested with Perfmon - GC has a delay in releasing memory as the allocations bubble up the generations, AKA, its slow
    # Seems only ending the script/session releases memory
    # Release Memory Benchmarking - Test setting a variable to $null vs using Remove-Variable
    # -------------------------------------------------------------------------
    
    $tbl = $null
    $storedProcs = $null
    $views = $null
    $udfs = $null
    $udtts = $null
    $catalog = $null
    $DBTriggers = $null    
    $Schemas = $null
    $Sequences = $null
    $Synonyms = $null
 
    [System.GC]::Collect()
}

# Return To Base
Set-Location $BaseFolder

