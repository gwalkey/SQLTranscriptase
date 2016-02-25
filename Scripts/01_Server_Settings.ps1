<#
.SYNOPSIS
    Gets the SQL Server Configuration Settings on the target server
	
.DESCRIPTION
   Writes the SQL Server Configuration Settings out to the "01 - Server Settings" folder
   One file for all settings
   Contains MinMax Memory, MAX DOP, Affinity, Cost Threshold, Network Packet size and other instance-level engine settings
   Helps to document a server that had non-default settings
   
.EXAMPLE
    01_Server_Settings.ps1 localhost
	
.EXAMPLE
    01_Server_Settings.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML Files
	
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
Write-Host  -f Yellow -b Black "01 - Server Settings"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Settings.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
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
        Write-Output ("SQL Version: {0}" -f $myver)
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


# Set Local Vars - SMO Object
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


# Create output folder
set-location $BaseFolder
$output_path = "$BaseFolder\$SQLInstance\01 - Server Settings\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


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



# Export it
$RunTime = Get-date

$myoutputfile4 = $output_path+"\Server_Settings.html"
$myHtml1 = $srv.Configuration.Properties | sort-object DisplayName | select Displayname, ConfigValue, runValue | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>$SqlInstance</H1><H2>Server Settings</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Server Roles"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

# ----------------------------
# Get Buffer Pool Extensions
# ----------------------------
if ($myver -like "12.0*" -or $myver -like "13.0*" -or $myver -like "14.0*" -or $myver -like "15.0*")
{

    $mySQLquery = "USE Master; select State, path, current_size_in_kb as sizeKB from sys.dm_os_buffer_pool_extension_configuration"


    # connect correctly
    if ($serverauth -eq "win")
    {
	    # .NET Method
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
	    $SqlAdapter.Fill($DataSet) | out-null

	    # Close connection to sql server
	    $Connection.Close()
	    $sqlresults = $DataSet.Tables[0].Rows

    }
    else
    {
	    # .NET Method
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
	    $SqlAdapter.Fill($DataSet) | out-null

	    # Close connection to sql server
	    $Connection.Close()
        $sqlresults = $DataSet.Tables[0].Rows

    }

    # Export BPE
    if ($?)
    {
        
        if ($sqlresults.state -eq 5)
        {
            Write-Output "Buffer-Pool Extensions are Configured"
            $strExport = "
            ALTER SERVER CONFIGURATION SET BUFFER POOL EXTENSION
            ON
            (
        	    FILENAME = N'" + $sqlresults.path + "'," +
            "   SIZE = " + $sqlresults.sizeKB +"KB"+"`r`n"+
        "    );"
    
            $strExport | out-file "$output_path\Buffer_Pool_Extension.sql" -Encoding ascii
        }
        else
        {
            "Buffer-Pool Extensions are Not Configured"
            "Buffer-Pool Extensions are Not Configured" | out-file "$output_path\Buffer_Pool_Extensions_are_NOT_Configured.sql" -Encoding ascii
        }
    }
}
else
{
    Write-Output "SQL 2014+ required for Buffer Pool Extensions"
}

# Return To Base
set-location $BaseFolder


