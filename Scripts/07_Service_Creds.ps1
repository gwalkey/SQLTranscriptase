<#
.SYNOPSIS
    Gets the NT Service Credentials used to start each SQL Server exe
	
.DESCRIPTION
    Writes the Service Credentials out to the "07 - Service Startup Creds" folder, 
	file "Service Startup Credentials.sql"
	
.EXAMPLE
    07_Service_Creds.ps1 localhost
	
.EXAMPLE
    07_Service_Creds.ps1 server01 sa password

.Inputs
    ServerName

.Outputs
	HTML Files
	
.NOTES

	
.LINK

	
#>

Param(
  [string]$SQLInstance='localhost'
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "07 - Service Credentials"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./07_Service_Creds.ps1 'SQLServerName'"
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

		# SQLCMD.EXE Method
        #$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
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

		# SQLCMD.EXE Method
    	#$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
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


# If SQLInstance is a named instance, drop the instance part so we can connect to the Windows server only
$pat = "\\"

if ($SQLInstance -match $pat)
{    
	$SQLInstance2 = $SQLInstance.Split('\')[0]
}
else
{
	$SQLInstance2 = $SQLInstance
}


# Lets trap some WMI errors
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'


# Get SQL Services with stardard names 
try
{
	$results1 = @()
	$results1 = gwmi -class win32_service  -computer $SQLInstance2 -filter "name like 'MSSQLSERVER%' or name like 'MsDtsServer%' or name like 'MSSQLFDLauncher%'  or Name like 'MSSQLServerOLAPService%'  or Name like 'SQL Server Distributed Replay Client%'  or Name like 'SQL Server Distributed Replay Controller%'  or Name like 'SQLBrowser%'  or Name like 'SQLSERVERAGENT%'  or Name like 'SQLWriter%'  or Name like 'ReportServer%' or Name like 'SQLAgent%' or Name like 'MSSQL%'" 
	if ($?)
	{
		Write-Output "Good WMI Connection"
	}
	else
	{
		$fullfolderpath = "$BaseFolder\$SQLInstance\"
		if(!(test-path -path $fullfolderPath))
		{
			mkdir $fullfolderPath | Out-Null
		}

		Write-Output "No WMI connection to target server"
		echo null > "$fullfolderpath\07 - Service Creds - WMI Could not connect.txt"
		Set-Location $BaseFolder
		exit
	}

}
catch
{
	$fullfolderpath = "$BaseFolder\$SQLInstance\"
	if(!(test-path -path $fullfolderPath))
	{
		mkdir $fullfolderPath | Out-Null
	}

	Write-Output "No WMI connection to target server"
	echo null > "$fullfolderpath\07 - Service Creds - WMI Could not connect.txt"
	Set-Location $BaseFolder
	exit
}

# Reset default PS error handler - to catch any WMI errors
$ErrorActionPreference = $old_ErrorActionPreference 


$fullfolderPath = "$BaseFolder\$sqlinstance\07 - Service Startup Creds"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# Create some CSS for help in column formatting
$myCSS = 
"
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

$myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii

# Export It
$RunTime = Get-date
$mySettings = $results1
$mySettings | select Name, StartName  | ConvertTo-Html  -PostContent "<h3>Ran on : $RunTime</h3>"  -PreContent "<h1>$SqlInstance</H1><H2>NT Service Credentials</h2>" -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"

Write-Output ("{0} NT Service Creds Exported" -f $results1.count)

set-location $BaseFolder
