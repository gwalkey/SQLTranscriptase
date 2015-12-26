<#
.SYNOPSIS
    Gets the SQL Agent Proxies
	
.DESCRIPTION
   Writes the SQL Agent Proxies out to the "04 - Agent Proxies" folder
   Proxies are typically used when you need to use alternate credentials in a job step
   For instance when calling an SSIS package that needs to connect with SQL Auth credentials for a DMZ/Non-Domain Server
   
.EXAMPLE
    04_Agent_Proxies.ps1 localhost
	
.EXAMPLE
    04_Agent_Proxies.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

.NOTES
	
.LINK

	
#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

#  Script Name
Write-Host  -f Yellow -b Black "04 - Agent Proxies"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Proxies.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


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



# Check for Express version and exit - No Agent
# Turn off default error handler
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'	

$EditionSQL = "SELECT SERVERPROPERTY('Edition')"

if ($serverauth -eq "win")
{
    $Edition = Invoke-SqlCmd -query $EditionSQL -Server $SQLInstance
}
else
{
    $Edition = Invoke-SqlCmd -query $EditionSQL  -Server $SQLInstance –Username $myuser –Password $mypass    
}

if ($Edition -ne $null )
{
    if ($edition.column1 -match "Express")
    {
        Write-Output ("Skipping '{0}'" -f $Edition.column1)
        exit
    }    
}

# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference 


function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
            try
            {
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
            }
            catch {}
			
			$myProxyname = $o.Name
			$myProxyname = $myProxyname.Replace('\', '-')
			$myProxyname = $myProxyname.Replace('/', '-')
			$myProxyname = $myProxyname.Replace('&', '-')
			$myProxyname = $myProxyname.Replace(':', '-')
			$myProxyname = $myProxyname.Replace('[', '(')
			$myProxyname = $myProxyname.Replace(']', ')')
			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $myProxyname + ".sql"
			$scripter.EnumScript($o)
		}
	}
}



# Set Local Vars
$server 	= $SQLInstance

if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter   = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)

}

$scripter.Options.ToFileOnly = $true


# create output folder
$proxy_path = "$BaseFolder\$sqlinstance\04 - Agent Proxies\"
if(!(test-path -path $proxy_path))
{
	mkdir $proxy_path | Out-Null
}

# Export Agent Proxy Object Collection
# Get Database Mail configuration objects
[int]$ProxyCount = 0;
try
{
    $ProxyCount = $srv.Jobserver.ProxyAccounts.Count
}
catch {}

if ($ProxyCount -gt 0)
{
    $pa = $srv.JobServer.ProxyAccounts
    CopyObjectsToFiles $pa $proxy_path
}

Write-Output ("{0} Agent Proxies Exported" -f $ProxyCount)

set-location $BaseFolder
