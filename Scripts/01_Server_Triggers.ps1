<#
.SYNOPSIS
    Gets the Server Triggers on the target server
	
.DESCRIPTION
   Writes the Server Triggers out to the "01 - Server Triggers" folder
   One file for all Triggers   
   
.EXAMPLE
    01_Server_Triggers.ps1 localhost
	
.EXAMPLE
    01_Server_Triggers.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "01 - Server Triggers"
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



$SQLCMD2 = 
"
SELECT
ssmod.definition AS [Definition],
'ENABLE TRIGGER ' + name +' ON ALL SERVER' as enablecmd
FROM
master.sys.server_triggers AS tr
LEFT OUTER JOIN master.sys.server_assembly_modules AS mod ON mod.object_id = tr.object_id
LEFT OUTER JOIN sys.server_sql_modules AS ssmod ON ssmod.object_id = tr.object_id
WHERE (tr.parent_class = 100)

"

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -ErrorAction Stop
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
        $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}
	

# If No Results, write status file
if ($sqlresults2 -eq $null)
{
    Write-Output "No Server Triggers Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\01 - No Server Triggers Found.txt"
    Set-Location $BaseFolder
    exit
}


# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Triggers"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

    
# Script Out
Foreach ($row in $sqlresults2)
{
    $row.Definition+"`r`nGO`r`n`r`n",$row.enableCMD+"`r`nGO`r`n" | out-file "$fullfolderPath\Server_Triggers.sql" -Encoding ascii -Append
	Add-Content -Value "`r`n" -Path "$fullfolderPath\Server_Triggers.sql" -Encoding Ascii
}

# Return To Base
set-location $BaseFolder
