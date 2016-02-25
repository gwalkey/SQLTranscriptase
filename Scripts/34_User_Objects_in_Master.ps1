<#
.SYNOPSIS
  Gets the Non-Microsoft objects in the Master Database
	
.DESCRIPTION
  Gets the Non-Microsoft objects in the Master Database
	
   
.EXAMPLE
    34_User_Objects_in_Master.ps1 localhost
	
.EXAMPLE
    34_User_Objects_in_Master.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML Files
	
.NOTES
	.NET DataAdapter faster and more sustainable than Invoke-SqlCmd

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
Write-Host  -f Yellow -b Black "34 - User Objects in Master DB" 


# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow -b black "Usage: ./34_User_Objects_in_Master.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        Write-Output "Trying SQL Auth"
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
        Write-Output "Trying Windows Auth"
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
    Write-Warning "$SQLInstance appears offline"
    Set-Location $BaseFolder
	exit
}



# Set Local Vars for SMO Object usage
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
$output_path = "$BaseFolder\$SQLInstance\34 - User Objects in Master DB\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

	
# SQL
$sql1 = 
"
SELECT
CASE WHEN  type = 'U' THEN 'TABLE '
               WHEN  type = 'P' THEN 'PROCEDURE '
               WHEN  type = 'FN'THEN 'FUNCTION '
               WHEN  type = 'V'THEN 'VIEW ' 
END as 'ObjectType',
[Name] 
FROM Master.sys.objects
WHERE is_ms_shipped <> 1
AND TYPE IN ('U','P','FN','V')
order by 1,2

"


# Run Query 1
Write-Output "Running SQL 1.."
if ($serverauth -ne "win")
{
    # .NET Method
	# Open connection and Execute sql against server using SQL Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql1
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$results = $DataSet.Tables[0].Rows

}
else
{
	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql1
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$results = $DataSet.Tables[0].Rows

}

# Use HTML Fragments for multiple tables and inline CSS
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

$myoutputfile4 = $output_path+"User_Objects_In_Master.html"
$myHtml1 = $results | select ObjectType, Name| ConvertTo-Html -Fragment -as table -PreContent "<h3>User Objects in Master Database on $SQLInstance </h3>"
Convertto-Html -head $head -Body "$myHtml1" -Title "User Objects in Master DB"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

set-location $BaseFolder