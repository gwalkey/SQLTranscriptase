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
Write-Host  -f Yellow -b Black "04 - Agent Proxies"
Write-Output "Server $SQLInstance"


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



# Check for Express version and exit - No Agent
$EditionSQL = "SELECT SERVERPROPERTY('Edition')"

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $Edition = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}
else
{
try
    {
        $Edition = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

if ($Edition -ne $null )
{
    if ($edition.column1 -match "Express")
    {
        Write-Output ("Skipping '{0}'" -f $Edition.column1)
        exit
    }    
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



# New UP SMO Object
if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($SQLInstance)
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
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
$ProxyCount = @($srv.Jobserver.ProxyAccounts).Count
if ($ProxyCount -gt 0)
{
    $pa = $srv.JobServer.ProxyAccounts
    CopyObjectsToFiles $pa $proxy_path
}

Write-Output ("{0} Agent Proxies Exported" -f $ProxyCount)

# Return to Base
set-location $BaseFolder
