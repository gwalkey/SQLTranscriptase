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

try
{
    Import-Module ".\LoadSQLSmo.psm1"
}
catch
{
    Throw('LoadSQLSmo.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "01 - Server Settings"
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


# New UP SMO Object
if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
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

    $SQLCMD3 = "USE Master; select State, path, current_size_in_kb as sizeKB from sys.dm_os_buffer_pool_extension_configuration"


    # Run Query
    if ($serverauth -eq "win")
    {
        try
        {
            $sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD3 -ErrorAction Stop
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
            $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD3 -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }

    # Export BPE
    if ($sqlresults3 -ne $null)
    {
        
        if ($sqlresults3.state -eq 5)
        {

            $strExport = 
"ALTER SERVER CONFIGURATION
SET BUFFER POOL EXTENSION ON
(FILENAME = N'" + $sqlresults3.path + "',SIZE = " + $sqlresults3.sizeKB +"KB);"
    
            $strExport | out-file "$output_path\Buffer_Pool_Extension.sql" -Encoding ascii
        }
        else
        {
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


