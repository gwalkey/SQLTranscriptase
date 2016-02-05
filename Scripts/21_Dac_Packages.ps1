<#
.SYNOPSIS
   Gets the DAC Packages registered on target server
	
.DESCRIPTION
   Writes the registered Dac Packages out to the "21 - DacPackages" folder
      
.EXAMPLE
    21_Dac_Packages.ps1 localhost
	
.EXAMPLE
    21_Dac_Packages.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    SQLPackage.exe to create the .dacpac files
    The Microsoft.SqlServer.Dac namespace from the DacFX library to register the Databases as Data-Tier Applications for Drift Reporting
    
    DaxFX 
    http://www.microsoft.com/en-us/download/details.aspx?id=45886

    Check the Registrations results here:
    select * from msdb.dbo.sysdac_instances

.LINK
	https://github.com/gwalkey
	
	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass,
  [int]$registerDAC=0
)


Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "21 - DAC Packages"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./21_Dac_Packages.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Load Additional Assemblies
$dacver = $null;
$dacdll = "C:\Program Files (x86)\Microsoft SQL Server\100\DAC\bin\Microsoft.SqlServer.Dac.dll"
if((test-path -path $dacdll))
{
    $dacver = 2008
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\100\DAC\bin\Microsoft.SqlServer.Dac.dll"
}

$dacdll = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\Microsoft.SqlServer.Dac.dll"
if((test-path -path $dacdll))
{
    $dacver = 2012
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\Microsoft.SqlServer.Dac.dll"
}

$dacdll = "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll"
if((test-path -path $dacdll))
{
    $dacver = 2014
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll"
}

$dacdll = "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll"
if((test-path -path $dacdll))
{
    $dacver = 2016
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll"
}

If (!($dacver))
{
    Write-Output "Microsoft.SqlServer.Dac.dll not found, exiting"
    exit
}


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
        $sqlver = $results.column1

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
        $sqlver = $results.column1

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



# Skip if server not 2008 R2+
if (!($sqlver -like "10.5*") -and !($sqlver -like "11.0*") -and !($sqlver -like "12.0*") -and !($sqlver -like "13.0*"))
{
    Write-Output "Dac Packages only supported on SQL Server 2008 R2 or higher"
    set-location $BaseFolder
    exit
}


# Set Local Vars
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


# Output Folder
Write-Output "$SQLInstance - Dac Packages"
$Output_path  = "$BaseFolder\$SQLInstance\21 - DAC Packages\"
if(!(test-path -path $Output_path))
{
    mkdir $Output_path | Out-Null
}

# Drift Reports
$DriftOutput_path  = "$BaseFolder\$SQLInstance\21 - DAC Packages\DriftReports\"
if(!(test-path -path $DriftOutput_path))
{
    mkdir $DriftOutput_path | Out-Null
}


# Check for existence of SqlPackage.exe and get latest version
$pkgver = $null;

$pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\100\DAC\bin\sqlpackage.exe"
if((test-path -path $pkgexe))
{
    $pkgver = $pkgexe
}

$pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\sqlpackage.exe"
if((test-path -path $pkgexe))
{
    $pkgver = $pkgexe
}

$pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\sqlpackage.exe"
if((test-path -path $pkgexe))
{
    $pkgver = $pkgexe
}

$pkgexe = "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\sqlpackage.exe"
if((test-path -path $pkgexe))
{
    $pkgver = $pkgexe
}

If (!($pkgver))
{
    Write-Output "SQLPackage.exe not found, exiting"
    exit
}

# 
Write-Output "Exporting Dac Packages..."

# Create Batch file to run below
$myoutstring = "@ECHO OFF`n" | out-file -FilePath "$Output_path\DacExtract.cmd" -Force -Encoding ascii

foreach($sqlDatabase in $srv.databases)
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}

    # Strip brackets from DBname
    $db = $sqlDatabase
    $myDB = $db.name
    $myServer = $SQLInstance   
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')

    # Skip Offline Databases (SMO still enumerates them, but cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

    set-location $Output_path
       
    # ----------------------------------------------
    # Script out DACPACs
    # ----------------------------------------------
    if ($serverauth -eq "win")
    {
        $myoutstring = [char]34+$pkgver + [char]34+ " /action:extract /sourcedatabasename:$myDB /sourceservername:$MyServer /targetfile:$MyDB.dacpac `n"
    }
    else
    {
        $myoutstring = [char]34+$pkgver + [char]34+ " /action:extract /sourcedatabasename:$myDB /sourceservername:$MyServer /targetfile:$MyDB.dacpac /sourceuser:$myuser /sourcepassword:$mypass `n"
    }
    $myoutstring | out-file -FilePath "$Output_path\DacExtract.cmd" -Encoding ascii -append

    # Register the Database as a Data Tier Application - if command-line parameter is set true
    if ($registerDAC -eq 1)
    {
        ## Specify the DAC metadata.
        $applicationname = $fixedDBName
        [system.version]$version = '1.0.0.0'
        $description = "Registered during DacPac Script-Out pass on "+(Get-Date).ToString()
        # Register as 1.0.0.0    
        try
        {
            $dac = new-object Microsoft.SqlServer.Dac.DacServices "server=$sqlinstance"
            $dac.register($myDB, $myDB, $version, $description)
			Write-Output ("Registered Database {0}" -f $myDB)
        }
        catch
        {
            Write-Output "DacServices Register of $myDB failed"
        }
        $dac = $null;
    }
    
    # -------------------------------
    # Create Drift Report batch file
    # -------------------------------
    $myDriftFileName = $DriftOutput_path+"\"+$myDB+"_DriftReport.cmd"
    $myDriftReportName = $myDB+"_DriftReport.xml"

    # SQLPackage.EXE needs DMZ username and password parameters passed in
    if ($serverauth -eq "win")
    {
        [char]34 + $pkgver + [char]34 + " /A:DriftReport /tsn:$myServer /tdn:$myDB /op:$myDriftReportName `n $myDriftReportName `n" | out-file -FilePath $myDriftFileName -Force -Encoding ascii
    }
    else
    {
        [char]34 + $pkgver + [char]34 + " /A:DriftReport /tsn:$myServer /tdn:$myDB /tu:$myuser /tp:$mypass /op:$myDriftReportName `n $myDriftReportName `n" | out-file -FilePath $myDriftFileName -Force -Encoding ascii
    }

    # ---------------------
    # Script out BACPACs
    # ---------------------
    if ($serverauth -eq "win")
    {
        $myoutstring = [char]34+$pkgver + [char]34+ " /action:export /sourcedatabasename:$myDB /sourceservername:$MyServer /targetfile:$MyDB.bacpac `n"
    }
    else
    {
        $myoutstring = [char]34+$pkgver + [char]34+ " /action:export /sourcedatabasename:$myDB /sourceservername:$MyServer /targetfile:$MyDB.bacpac /sourceuser:$myuser /sourcepassword:$mypass `n"
    }
    $myoutstring | out-file -FilePath "$Output_path\BacExport.cmd" -Encoding ascii -append



}

# Run the SQLPACKAGE batch files
.\DacExtract.cmd
.\BacExport.cmd

# Remember to run the Drift Report batch files in the DriftReports folder

remove-item -Path "$Output_path\DacExtract.cmd" -Force -ErrorAction SilentlyContinue
remove-item -Path "$Output_path\BacExport.cmd" -Force -ErrorAction SilentlyContinue

# Return to Base
set-location $BaseFolder



