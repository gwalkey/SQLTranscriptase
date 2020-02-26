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
	https://github.com/gwalkey
	
#>

[CmdletBinding()]
Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "07 - Service Credentials"
Write-Output("Server: [{0}]" -f $SQLInstance)


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

[int]$ver = GetSQLNumericalVersion $myver



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

# Export Creds
$RunTime = Get-date

$myoutputfile4 = $FullFolderPath+"\NT_Service_Credentials.html"
$myHtml1 = $results1 | select Name, StartName, StartMode | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>SQL Server Related NT Service Credentials</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "NT Service Credentials"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

Write-Output ("{0} NT Service Creds Exported" -f $results1.count)

# Return To Base
set-location $BaseFolder

