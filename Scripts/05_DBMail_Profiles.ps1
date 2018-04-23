<#
.SYNOPSIS
    Gets the SQL Agent Database Mail Profiles
	
.DESCRIPTION
    Writes the SQL Agent Database Mail Profiles out to DBMail_Accounts.sql
	
.EXAMPLE
    05_DBMail_Profiles.ps1 localhost
	
.EXAMPLE
    05_DBMail_Profiles.ps1 server01 sa password
	
.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
    DBMail Profiles to DBMAIL_Profiles.sql
	
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
Write-Host  -f Yellow -b Black "05 - DBMail Profiles"
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

# Get Database Mail configuration objects
$ProfileCount = @($srv.Mail.Profiles).Count

# Export Them
if ($ProfileCount -gt 0)
{
    $DBMProfiles = $srv.Mail.Profiles

    # Create output folder
    $fullfolderPath = "$BaseFolder\$sqlinstance\05 - DBMail Profiles"
    if(!(test-path -path $fullfolderPath))
    {
    	mkdir $fullfolderPath | Out-Null
    }

    # Create Output File
    New-Item "$fullfolderPath\DBMail_Profiles.sql" -type file -force  |Out-Null
    
    # Row Process
    Foreach ($row in $DBMProfiles)
    {
        $ProfileScript = $row.Script()
        $ProfileScript | out-file "$fullfolderPath\DBMail_Profiles.sql" -Encoding ascii -Append
    }
    
    Write-Output ("{0} DBMail Profiles Exported" -f $DBMProfiles.count)
}
else
{
    Write-Output "No Database Mail Profiles found on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\05 - No Database Mail Profiles found.txt"
    Set-Location $BaseFolder    
}

# Return To Base
set-location $BaseFolder



