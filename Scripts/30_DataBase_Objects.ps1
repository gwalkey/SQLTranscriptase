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
	
#>

Param(
    [string]$SQLInstance = "localhost",
    [string]$myuser,
    [string]$mypass,
    [string]$myDatabase,
	[string]$mytable

)

Set-StrictMode -Version latest;

$DebugPreference = "Stop"

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "30 - DataBase Objects"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./30_DataBase_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}

# Parameter check: Table needs matching Database parameter
if ($myTable.Length -gt 0 -and $myDatabase.Length -eq 0)
{
    Write-Output ("Please specify the -MyDatabase parameter when using -myTable with {0}" -f $mytable)
    exit
}

# Working
Write-Output "Server $SQLInstance"


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
		$myver = $results.Column1
        Write-Output ("SQL Version: {0}" -f $results.Column1)
    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference 	

}
catch
{
    Write-Warning "$SQLInstance appears offline - Try Windows Authorization."
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
			
            try
            {
			    if ($o.Schema -ne $null -and $o.Schema -ne "") 
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
                $urn = new-object Microsoft.SQlserver.Management.sdk.sfc.urn($o.Urn);
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


# Set Local Vars
$server = $SQLInstance

if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
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

# Db and Table Objects
#$db 	= New-Object ("Microsoft.SqlServer.Management.SMO.Database")
#$tbl	= New-Object ("Microsoft.SqlServer.Management.SMO.Table")

# Set Speed=On trick - doesnt work on Scripting - But thanks for the tip MVP Ben Miller
# $tbl.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "CreateDate")

# Find/Inspect other Server-Level Objects here
Write-Output "Looking for Objects..."

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
$mySQLquery = 
"
SELECT 
    DB_NAME([database_id]) AS [Database_Name],
    [file_id],
    name as 'Name',
    physical_name as 'FileName',
    type_desc as 'Type',
    state_desc as 'State',
	case when is_percent_growth=1 then '%' else 'MB' end as 'Growth',
	case when is_percent_growth=1 then growth else CONVERT(float, growth/128.0) end AS [Growth_in_MB],
    CONVERT(float, size/128.0) AS [DB_Size_in_MB]
FROM sys.master_files WITH (NOLOCK)
ORDER BY DB_NAME([database_id]) OPTION (RECOMPILE);
"

#Run SQL
if ($serverauth -eq "win")
{
    # .Net Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySQLquery
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) |out-null

	# Close connection to sql server
	$Connection.Close()
	$sqlresultsX = $DataSet.Tables[0].Rows

}
else
{
    # .Net Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySQLquery
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) |out-null

	# Close connection to sql server
	$Connection.Close()
	$sqlresultsX = $DataSet.Tables[0].Rows

}

$RunTime = Get-date
$FullFolderPath = "$BaseFolder\$SQLInstance\30 - DataBase Objects\"
if(!(test-path -path $FullFolderPath))
{
    mkdir $FullFolderPath | Out-Null
}

$myoutputfile4 = $FullFolderPath+"\Database_Summary.html"
$myHtml1 = $sqlresultsX | select Database_Name,file_id, Name, FileName, Type, State, growth, growth_in_mb, DB_Size_in_MB | ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Database Summary</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Database Summary"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

# Create Database Object Reconstruction Order Hints File
"Database Object Reconstruction Order" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"`n " | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"01) Database itself with Filegroups and Files" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"02) .NET Assemblies" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"03) Linked Servers" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append    
"04) Logins" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append    
"05) Sequences" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"06) Synonyms" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"07) Schemas" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"08) UDFs (Table-Valued and Scalar Functions)" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"09) User-Defined Table Types" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"10) Tables (with DRI Dependencies)" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"11) Views" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"12) Stored Procedures" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"13) Full-Text Catalogs" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"14) Table Triggers" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append
"15) Database Triggers" | out-file "$FullFolderPath\Database_Reconstruction_Hints.txt" -Encoding ascii -Append

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

# WithDependencies create one huge file for all tables in the order needed to maintain RefIntegrity
$scripter.Options.WithDependencies		= $false # Leave OFF - creates issues - Jan 2016 we script out the DRO Tabel Order in a separate file now
$scripter.Options.XmlIndexes            = $true

# Set scripter options to ensure only schema is scripted
$scripter.Options.ScriptSchema 	= $true;
$scripter.Options.ScriptData 	= $false;

if ($myDatabase.Length -gt 0)
{
    Write-Output ("Only for Database {0}"-f $myDatabase)
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
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB','distribution') {continue}

    # Skip Offline Databases (SMO still enumerates them, but cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\30 - DataBase Objects\$fixedDBname"

    # paths
    $DB_Path                     = "$output_path\"
    $table_path 		         = "$output_path\Tables\"
    $TableTriggers_path	         = "$output_path\TableTriggers\"
    $views_path 		         = "$output_path\Views\"
    $storedProcs_path 	         = "$output_path\StoredProcedures\"
    $udfs_path 			         = "$output_path\UserDefinedFunctions\"
    $textCatalog_path 	         = "$output_path\FullTextCatalogs\"
    $udtts_path 		         = "$output_path\UserDefinedTableTypes\"
    $DBTriggers_path 	         = "$output_path\DBTriggers\"
    $Schemas_path                = "$output_path\Schemas\"
    $Filegroups_path             = "$output_path\Filegroups\"
    $Sequences_path              = "$output_path\Sequences\"
    $Synonyms_path               = "$output_path\Synonyms\"
    $DBScoped_Creds_path         = "$output_path\DBScopedCredentials\"
    $QueryStore_path             = "$output_path\QueryStore\"
    $DBEDS_path                  = "$output_path\ExternalDataSources\"
    $DBExtFF_path                = "$output_path\ExternalFileFormats\"
    $DBSecPol_path               = "$output_path\SecurityPolicies\"
    $XMLSC_path                  = "$output_path\XMLSchemaCollections\"
    $DBColumnEncryptionKey_path  = "$output_path\ColumnEncryptionKeys\"
    $DBColumnMasterKey_path      = "$output_path\ColumnMasterKeys\"
     

    # --------------------------------
    # Start Exporting Database Objects
    # --------------------------------

    # Main DB Export Folder
    if(!(test-path -path $DB_Path))
    {
        mkdir $DB_Path | Out-Null	
    }

    # Export Main Database Itself with Files and FileGroups
    Write-Output "$fixedDBName - Database"
    $MainDB = $db  | Where-object  { -not $_.IsSystemObject  }
    $myoutputfile = $DB_Path + $fixedDBName + ".sql"
    $MainDB.Script() | out-file -FilePath $myoutputfile -encoding ascii -Force

	# 2016+ Only Features
	if ($myver -like "13.0*")
	{
		# Database Scoped Credentials
		Write-Output "$fixedDBName - Database Scoped Credentials"
		$DBScopedCreds = $db.DatabaseScopedCredentials 
		CopyObjectsToFiles $DBScopedCreds $DBScoped_Creds_path

		# QueryStore Options
		Write-Output "$fixedDBName - Query Store Options"
		$myoutputfile = $QueryStore_path + "Query_Store.sql"
		$QueryStore = $db.QueryStoreOptions 
		if ($QueryStore -ne $null)
		{
			if(!(test-path -path $QueryStore_path))
			{
				mkdir $QueryStore_path | Out-Null	
			}
			$QueryStore.Script() | out-file -FilePath $myoutputfile -append -encoding ascii
		}
    
		# External Data Sources
		Write-Output "$fixedDBName - External Data Sources"
		$DB_EDS = $db.ExternalDataSources
		CopyObjectsToFiles $DB_EDS $DBEDS_path

		# External File Formats
		Write-Output "$fixedDBName - External File Formats"
		$DBExtFF = $db.ExternalFileFormats
		CopyObjectsToFiles $DBExtFF $DBExtFF_path

		# Security Policies
		Write-Output "$fixedDBName - Database Security Policies"
		$DBSecPol = $db.SecurityPolicies
		CopyObjectsToFiles $DBSecPol $DBSecPol_path

		# XMLSchema Collections
		Write-Output "$fixedDBName - XML Schema Collections"
		$DBXML_SC = $db.XmlSchemaCollections
		CopyObjectsToFiles $DBXML_SC $XMLSC_path

		# Always Encrypted Column Encryption Keys
		Write-Output "$fixedDBName - Column Encryption Keys"
		$DBAE_CEK = $db.ColumnEncryptionKeys
		CopyObjectsToFiles $DBAE_CEK $DBColumnEncryptionKey_path

		# Always Encrypted Column Master Keys
		Write-Output "$fixedDBName - Column Master Keys"
		$DBAE_CMK = $db.ColumnMasterKeys
		CopyObjectsToFiles $DBAE_CMK $DBColumnMasterKey_path

	}
        
    # Create Settings Path
    $DBSettingsPath = $output_path+"\Settings"

    if(!(test-path -path $DBSettingsPath))
    {
        mkdir $DBSettingsPath | Out-Null	
    }
   
       
    # Database Settings
    Write-Output "$fixedDBName - Settings"
    $mySettings = $db.Properties
    
    $myoutputfile4 = $DBSettingsPath+"\Database_Settings.html"
    $myHtml1 = $mySettings | sort-object Name | select Name, Value | ConvertTo-Html -Fragment -as table -PreContent "<h3>Database Settings for: $SQLInstance </h3>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Database Settings"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4
    
    #$mySettings | sort-object Name | select Name, Value | ConvertTo-Html  -CSSUri "$DBSettingsPath\HTMLReport.css"| Set-Content "$DBSettingsPath\HtmlReport.html"
       
    # Tables
    Write-Output "$fixedDBName - Tables"

    if ($mytable.Length -gt 0 -and $myDatabase -eq $sqldatabase.name)
	{
        Write-Output ("Only for table {0}"-f $mytable)
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
    Write-Output "$fixedDBName - Stored Procs"
    $storedProcs = $db.StoredProcedures | Where-object  {-not $_.IsSystemObject  }
    CopyObjectsToFiles $storedProcs $storedProcs_path

    # Views
    Write-Output "$fixedDBName - Views"
    $views = $db.Views | Where-object { -not $_.IsSystemObject   } 
    CopyObjectsToFiles $views $views_path

    # UDFs
    Write-Output "$fixedDBName - UDFs"
    $udfs = $db.UserDefinedFunctions | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $udfs $udfs_path

    # Table Types
    Write-Output "$fixedDBName - Table Types"
    $udtts = $db.UserDefinedTableTypes  
    CopyObjectsToFiles $udtts $udtts_path

    # FullTextCats
    Write-Output "$fixedDBName - FullTextCatalogs"
    $catalog = $db.FullTextCatalogs
    CopyObjectsToFiles $catalog $textCatalog_path

    # DB Triggers
    Write-Output "$fixedDBName - Database Triggers"
    $DBTriggers	= $db.Triggers
    CopyObjectsToFiles $DBTriggers $DBTriggers_path

    # Schemas
    Write-Output "$fixedDBName - Schemas"
    $Schemas = $db.Schemas | Where-object  { -not $_.IsSystemObject  }
    CopyObjectsToFiles $Schemas $Schemas_path

    # Sequences
    Write-Output "$fixedDBName - Sequences"
    $Sequences = $db.Sequences
    CopyObjectsToFiles $Sequences $Sequences_path

    # Synonyms
    Write-Output "$fixedDBName - Synonyms"
    $Synonyms = $db.Synonyms
    CopyObjectsToFiles $Synonyms $Synonyms_path

    # List Filegroups, Files and Path
    Write-Output "$fixedDBName - FileGroups"

    # Process FileGroups
    # Create output folder
    $myoutputfile = $Filegroups_path+"Filegroups.txt"
    if(!(test-path -path $Filegroups_path))
    {
        mkdir $Filegroups_path | Out-Null	
    }

    # Create Output File
    out-file -filepath $myoutputfile -encoding ascii -Force
    Add-Content -path $myoutputfile -value "FileGroupName:          DatabaseFileName:           FilePath:"

    # Prep SQL for Filegroups
    $mySQLquery = "USE $db; SELECT `
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

    #Run SQL
    if ($serverauth -eq "win")
    {
        # .Net Method
	    # Open connection and Execute sql against server using Windows Auth
    	$DataSet = New-Object System.Data.DataSet
    	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
    	$Connection = New-Object System.Data.SqlClient.SqlConnection
    	$Connection.ConnectionString = $SQLConnectionString
    	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    	$SqlCmd.CommandText = $mySQLquery
    	$SqlCmd.Connection = $Connection
    	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    	$SqlAdapter.SelectCommand = $SqlCmd
    
    	# Insert results into Dataset table
    	$SqlAdapter.Fill($DataSet) |out-null

    	# Close connection to sql server
    	$Connection.Close()
	    $sqlresults2 = $DataSet.Tables[0].Rows   		

    }
    else
    {
        # .Net Method
	    # Open connection and Execute sql against server
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $mySQLquery
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) |out-null

    	# Close connection to sql server
    	$Connection.Close()
    	$sqlresults2 = $DataSet.Tables[0].Rows        

    }

    # Script Out
    foreach ($FG in $sqlresults2)
    {
        $myoutputstring = $FG.FileGroupName+$FG.DatabaseFileName+$FG.DatabaseFilePath
        $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
    }


    # Table Creation in Dependency Order to maintain DRI
    Write-Output "$fixedDBName - DRI Create Table Order"

    # Create Database Summary Listing
    $mySQLquery4 = 
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

    # DataAdapter returns null for strange DB Names (Sharepoint etc) so trap them
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    #Run SQL
    if ($serverauth -eq "win")
    {
        # .Net Method
	    # Open connection and Execute sql against server using Windows Auth
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $mySQLquery4
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
        $SqlAdapter.SelectCommand.CommandTimeout=300;
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) |out-null

	    # Close connection to sql server
	    $Connection.Close()
	    $sqlresults4 = $DataSet.Tables[0].Rows

    }
    else
    {
        # .Net Method
	    # Open connection and Execute sql against server
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand        
	    $SqlCmd.CommandText = $mySQLquery4
	    $SqlCmd.Connection = $Connection   
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
        $SqlAdapter.SelectCommand.CommandTimeout=300;
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) |out-null

	    # Close connection to sql server
	    $Connection.Close()
	    $sqlresults4 = $DataSet.Tables[0].Rows

    }

    # Reset default PS error handler
    $ErrorActionPreference = $old_ErrorActionPreference

    $RunTime = Get-date
    $FullFolderPath = "$BaseFolder\$SQLInstance\30 - DataBase Objects\"
    if(!(test-path -path $FullFolderPath))
    {
        mkdir $FullFolderPath | Out-Null
    }
           
    
    "Create Your Tables in this order to maintain Declarative Referential Integrity`r`n" | out-file "$output_path\DRI_Table_Creation_Order.txt" -Encoding ascii
    $sqlresults4 | select Ordinal, TableName | out-file "$output_path\DRI_Table_Creation_Order.txt" -Encoding ascii -Append


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
    $TableTriggers = $null
    $Schemas = $null
    $Sequences = $null
    $Synonyms = $null

    <#    
    Remove-Variable $tbl
    Remove-Variable $storedProcs
    Remove-Variable $views
    Remove-Variable $udfs
    Remove-Variable $udtts
    Remove-Variable $catalog
    Remove-Variable $DBTriggers
    Remove-Variable $TableTriggers
    Remove-Variable $Schemas
    Remove-Variable $Sequences
    Remove-Variable $Synonyms 
    #>
    
    [System.GC]::Collect()

    <#
    Write-Output "Ending Memory: $db"
    [System.gc]::gettotalmemory("forcefullcollection") /1MB

    ps powershell* | Select *memory* | ft -auto `
    @{Name='VirtualMemMB';Expression={($_.VirtualMemorySize64)/1MB}}, `
    @{Name='PrivateMemMB';Expression={($_.PrivateMemorySize64)/1MB}}
    #>

    # Process Other Objecs    

    # Process Next Database
}




# Return To Base
set-location $BaseFolder

