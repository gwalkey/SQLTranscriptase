<#
.SYNOPSIS
    Dumps Table Data to BCP Native Format files

.DESCRIPTION
    Dumps Table Data to BCP Native Format files

.EXAMPLE
    31_DataBase_Export_Table_Data

.EXAMPLE
    31_DataBase_Export_Table_Data sa password

.Inputs
    ServerName, [SQLAuthUser], [SQLAuthPassword], [myDatabase], [myTable]


.Outputs

.NOTES

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

Write-Host  -f Yellow -b Black "31 - DataBase Export Table Data"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./31_DataBase_Export_Table_Data.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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



# Create SMO Object
$server = $SQLInstance

if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
}

$RunTime = Get-date
$FullFolderPath = "$BaseFolder\$SQLInstance\31 - DataBase Table Data"
if(!(test-path -path $FullFolderPath))
{
    mkdir $FullFolderPath | Out-Null
}


if ($myDatabase.Length -gt 0)
{
    Write-Output ("Database: {0}"-f $myDatabase)
}

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{
	# If only one database specified on the command-line, ignore/skip all others
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
    $output_path = $FullFolderPath+"\$fixedDBname"

    # paths
    $DB_Path = "$output_path"

    if(!(test-path -path $DB_Path))
    {
        mkdir $DB_Path | Out-Null
    }

    
    # --------------------------------
    # Start Exporting Table Data
    # --------------------------------
    foreach ($DBTable in $db.tables)
    {

        # Check for Single Table requested in cmd line parameter
        if ($myTable.Length -gt 0 -and $mytable -ne $DBTable.name) {continue}

        Write-Output ("Table: {0}" -f $DBTable.name)

        # Breakout TableName   
        $tblSchema = ($DBTable -split {$_ -eq "."})[0]
        $tblTable = ($DBTable -split {$_ -eq "."})[1]

        $tblSchema2 = $tblSchema
        $tblSchema2 = $tblSchema2.replace('[','')
        $tblSchema2 = $tblSchema2.replace(']','')
        $tblSchema2 = $tblSchema2.replace(' ','_')

        $tblTable2 = $tblTable
        $tblTable2 = $tblTable2.replace('[','')
        $tblTable2 = $tblTable2.replace(']','')
        $tblTable2 = $tblTable2.replace(' ','_')

        $FileFullName = $DB_Path+"\"+$tblSchema2+"."+$tblTable2+".dat"
        $FileFormatFullName = $DB_Path+"\"+$tblSchema2+"."+$tblTable2+".fmt"

        # Windows Auth
        if ($serverauth -eq "win")
        {
            # Create Batch files to run the export itself, and call those
            # Data
            $myoutstring = "@echo off `r`nbcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" out "+[char]34+$FileFullName+[char]34 + " -n -T -S " +$SQLInstance + "`n"
            #$myoutstring
            $myoutstring | out-file -FilePath "$DB_Path\BCPTableDump.cmd" -Force -Encoding ascii

            # Format File
            #$myformatstring = "@echo off `n bcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" format nul -T -n -S "+$SQLInstance + " -f "+[char]34+$FileFormatFullName+[char]34+ "`n"
            #$myformatstring
            #$myformatstring | out-file -FilePath "$DB_Path\BCPTableFormat.cmd" -Force -Encoding ascii

            # Import ETL
            $myImportETL = "bcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" in "+[char]34+$FileFullName+[char]34 + " -n -T -S " +$SQLInstance + "`n"
            #$myImportETL
            $myImportETL | out-file -FilePath "$DB_Path\BCPTableImport.cmd" -append -Encoding ascii

            set-location $DB_Path

            .\BCPTableDump.cmd
            #.\BCPTableFormat.cmd

            set-location $BaseFolder

        }
        else
        # SQL Auth
        {
            # Create Batch files to run the export itself, and call those
            # Data
            $myoutstring = "bcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" out "+[char]34+$FileFullName+[char]34 + " -n -S " +$SQLInstance + " -U "+$myUser + " -P "+ $myPass
            $myoutstring | out-file -FilePath "$DB_Path\BCPTableDump.cmd" -Force -Encoding ascii

            # Format File
            #$myformatstring = "bcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" format nul -n -S "+$SQLInstance + " -f "+[char]34+$FileFormatFullName+[char]34 + " -U "+$myUser + " -P "+ $myPass
            #$myformatstring | out-file -FilePath "$DB_Path\BCPTableFormat.cmd" -Force -Encoding ascii

            # Import ETL
            $myImportETL = "bcp ["+$fixedDBName+"]."+$tblSchema+"."+$tblTable+" in "+[char]34+$FileFullName+[char]34 + " -n -T -S " +$SQLInstance + " -U "+$myUser + " -P "+ $myPass + "`n"
            $myImportETL
            $myImportETL | out-file -FilePath "$DB_Path\BCPTableImport.cmd" -append -Encoding ascii


            set-location $DB_Path

            .\BCPTableDump.cmd | Out-Null
            #.\BCPTableFormat.cmd | out-null

            set-location $BaseFolder
        }




    } # Next Table

    set-location $DB_Path
    remove-item -Path "$DB_Path\BCPTableDump.cmd"
    set-location $BaseFolder

} # Next Database


# Return To Base
set-location $BaseFolder


