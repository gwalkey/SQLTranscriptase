<#
.SYNOPSIS
    Runs all other Powershell ps1 scripts for the target server
	
.DESCRIPTION
    Runs all other Powershell ps1 scripts for the target server    
	
.EXAMPLE
    00_RunAllScriptsSecurityOnly.ps1 localhost
	
.EXAMPLE
    00_RunAllScriptsSecurityOnly.ps1 server01 sa password

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

# --- TIPS ---
# Want to Register these or your own scripts as a Powershell Module?
# Rename them from .ps1 to .psm1 and put them in one of the folders pointed to by
# $env:PSModulePath (the Windows Environment path)


cls

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO



# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./00_RunAllScripts.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
	set-location "$BaseFolder"
    exit
}

# Server connection check
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "$SQLInstance - Testing SQL Auth"
	try{
    $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 #-erroraction SilentlyContinue
    if($results -ne $null)
    {
        $myver = $results.Column1
        Write-Output $myver
    }	
	}
	catch{
		Write-Host -f red "$SQLInstance not installed/running or is offline - Try Windows Auth?"
		exit
	}
}
else
{
	Write-Output "$SQLInstance - Testing Windows Auth"
 	Try{
    $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
    if($results -ne $null)
    {
        $myver = $results.Column1
        Write-Output $myver
    }
	}
	catch {
	Write-Host -f red "$SQLInstance not installed/running or is offline - Try SQL Auth?" 
	exit
	}

}


set-location "$BaseFolder"

& .\01_Server_Logins.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Credentials.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Roles.ps1 $SQLInstance $myuser $mypass
& .\02_Linked_Servers.ps1 $SQLInstance $myuser $mypass
& .\07_Service_Creds.ps1 $SQLInstance $myuser $mypass
& .\12_Security_Audit.ps1 $SQLInstance $myuser $mypass
& .\13_PKI.ps1 $SQLInstance $myuser $mypass


set-location "$BaseFolder"
exit
