<#
.SYNOPSIS
    Runs all other Powershell ps1 scripts for the target server
	
.DESCRIPTION
    Runs all other Powershell ps1 scripts for the target server    
	
.EXAMPLE
    00_RunAllScripts.ps1 localhost
	
.EXAMPLE
    00_RunAllScripts.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
	Testing TFS Versioning
	
.LINK
	
#>


Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass,
  [int]$timestamp = 0
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

# Load More Assemblies
# Add-type �assemblyname system.speech | Out-Null
# $talker = New-Object System.Speech.Synthesis.SpeechSynthesizer

$startTime = get-date

#  Script Name
Write-Host -f Yellow -b Black "00 - RunAllScripts"
#$talker.speak("Scripting started at $((Get-Date).ToShortTimeString())")

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Server connection check
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "$SQLInstance - Testing SQL Auth"
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 #-erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
        }	
	}
	catch
    {
		Write-Host -f red "$SQLInstance not installed/running or is offline - Try Windows Auth?"
		exit
	}
}
else
{
	Write-Output "$SQLInstance - Testing Windows Auth"
 	Try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
        }
    }
	catch
    {
	    Write-Host -f red "$SQLInstance not installed/running or is offline - Try SQL Auth?" 
	    exit
	}

}


set-location $BaseFolder

& .\01_Server_Appliance.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Credentials.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Logins.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Resource_Governor.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Roles.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Settings.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Shares.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Storage.ps1 $SQLInstance $myuser $mypass
& .\01_Server_Triggers.ps1 $SQLInstance $myuser $mypass
& .\02_Linked_Servers.ps1 $SQLInstance $myuser $mypass
& .\03_NET_Assemblies.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Jobs.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Alerts.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Operators.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Proxies.ps1 $SQLInstance $myuser $mypass
& .\04_Agent_Schedules.ps1 $SQLInstance $myuser $mypass
& .\05_DBMail_Accounts.ps1 $SQLInstance $myuser $mypass
& .\05_DBMail_Profiles.ps1 $SQLInstance $myuser $mypass
& .\07_Service_Creds.ps1 $SQLInstance
& .\09_SSIS_Packages_from_MSDB.ps1 $SQLInstance $myuser $mypass
& .\09_SSIS_Packages_from_SSISDB.ps1 $SQLInstance $myuser $mypass
& .\10_SSAS_Objects.ps1 $SQLInstance $myuser $mypass
& .\11_SSRS_Objects.ps1 $SQLInstance $myuser $mypass
& .\12_Security_Audit.ps1 $SQLInstance $myuser $mypass
& .\13_PKI.ps1 $SQLInstance $myuser $mypass
& .\14_Service_Broker.ps1 $SQLInstance $myuser $mypass
& .\15_Extended_Events.ps1 $SQLInstance $myuser $mypass
& .\16_Audits.ps1 $SQLInstance $myuser $mypass
& .\17_Managed_Backups.ps1 $SQLInstance $myuser $mypass
# & .\18_Replication.ps1 $SQLInstance $myuser $mypass
# & .\19_AlwaysOn.ps1 $SQLInstance $myuser $mypass
& .\21_Dac_Packages.ps1 $SQLInstance $myuser $mypass
& .\22_Policy_Based_Mgmt.ps1 $SQLInstance $myuser $mypass
& .\23_Database_Diagrams.ps1 $SQLInstance $myuser $mypass
& .\24_Plan_Guides.ps1 $SQLInstance $myuser $mypass




Write-Output "`r`n"
$ElapsedTime = ((get-date) - $startTime)
Write-Output ("$SQLInstance Elapsed time: {0:00}:{1:00}:{2:00}.{3:0000}" -f $ElapsedTime.Hours,$ElapsedTime.Minutes,$ElapsedTime.Seconds, $ElapsedTime.TotalMilliseconds)

# TimeStamp the output folder for DIFF Operations
if($timestamp -eq 1)
{
    $currentTime = get-date -f yyyy_MM_dd_HH_mm_ss
    $oldFoldername = $baseFolder+"\"+$sqlinstance
    $NewFolderName = $baseFolder+"\"+$sqlinstance+"_"+$currentTime
    rename-item -path $oldFoldername -NewName $NewFolderName -force
}

# $talker = New-Object System.Speech.Synthesis.SpeechSynthesizer
# $talker.speak("Scripting Success. You are the Man $env:USERNAME")

set-location $BaseFolder
exit
