<#
.SYNOPSIS
    Gets the SQL Agent configuration properies of the targeted SQL server
	
.DESCRIPTION
    Uses SMO Object DLLs
	
.EXAMPLE
    04_Agent_Configuration.ps1 localhost
	
.EXAMPLE
    04_Agent_Configuration.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK
	https://github.com/gwalkey
	
#>

[CmdletBinding()]
Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance='localhost',

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,50)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,50)]
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
[string]$BaseFolder = (get-location).path
Write-Host -f Yellow -b Black "04 - Agent Configuration"
Write-Output("Server: [{0}]" -f $SQLInstance)

# Server connection check
$SQLCMD1 = "select serverproperty('productversion') as 'Version'"
try
{
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"        
        $myver = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop| Select-Object -ExpandProperty Version
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		$myver = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop | Select-Object -ExpandProperty Version
        $serverauth = "win"
    }

    if($null -ne $myver)
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

# Create folder
$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Configuration"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

# New UP SMO Server Object
if ($serverauth -eq "win")
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}
else
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
        $srv.ConnectionContext.LoginSecure=$false
        $srv.ConnectionContext.set_Login($myuser)
        $srv.ConnectionContext.set_Password($mypass)    
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}


# Create File and Header
$fullFileName = $fullfolderPath+"\04_Agent_Configuration.txt"
New-Item $fullFileName -type file -force | Out-Null
$Now = (Get-Date -f "MM/dd/yyyy HH:mm:ss.fff")
Write-Output("{0} - SQL Agent Configuration for [{1}] `r`n" -f $now, $SQLInstance) | out-file $fullFileName -Encoding Ascii -Append

# Create Datatable for table-based formatting
$DataTable = New-Object System.Data.DataTable
$DataTable.Columns.Add("Setting","string") | out-null
$DataTable.Columns.Add("Value","string") | out-null

# Get Agent Configuration Settings using SMO
$Agent = $srv.JobServer

[void]$DataTable.Rows.Add('AgentDomainGroup',$Agent.AgentDomainGroup)
[void]$DataTable.Rows.Add('AgentLogLevel',$Agent.AgentLogLevel)
[void]$DataTable.Rows.Add('AgentShutdownWaitTime',$Agent.AgentShutdownWaitTime)
[void]$DataTable.Rows.Add('AlertSystem',$Agent.AlertSystem)
[void]$DataTable.Rows.Add('DatabaseEngineType',$Agent.DatabaseEngineType)
[void]$DataTable.Rows.Add('DatabaseEngineEdition',$Agent.DatabaseEngineEdition)
[void]$DataTable.Rows.Add('DatabaseMailProfile',$Agent.DatabaseMailProfile)
[void]$DataTable.Rows.Add('ErrorLogFile',$Agent.ErrorLogFile)
[void]$DataTable.Rows.Add('ExecutionManager',$Agent.ExecutionManager)
[void]$DataTable.Rows.Add('HostLoginName',$Agent.HostLoginName)
[void]$DataTable.Rows.Add('IdleCpuDuration',$Agent.IdleCpuDuration)
[void]$DataTable.Rows.Add('IdleCpuPercentage',$Agent.IdleCpuPercentage)
[void]$DataTable.Rows.Add('IsCpuPollingEnabled',$Agent.IsCpuPollingEnabled)
[void]$DataTable.Rows.Add('JobServerType',$Agent.JobServerType)
[void]$DataTable.Rows.Add('JobServerType',$Agent.JobServerType)
[void]$DataTable.Rows.Add('LocalHostAlias',$Agent.LocalHostAlias)
[void]$DataTable.Rows.Add('LoginTimeout',$Agent.LoginTimeout)
[void]$DataTable.Rows.Add('MaximumHistoryRows',$Agent.MaximumHistoryRows)
[void]$DataTable.Rows.Add('MaximumJobHistoryRows',$Agent.MaximumJobHistoryRows)
[void]$DataTable.Rows.Add('MsxAccountCredentialName',$Agent.MsxAccountCredentialName)
[void]$DataTable.Rows.Add('MsxAccountName',$Agent.MsxAccountName)
[void]$DataTable.Rows.Add('MsxServerName',$Agent.MsxServerName)
[void]$DataTable.Rows.Add('Name',$Agent.Name)
[void]$DataTable.Rows.Add('NetSendRecipient',$Agent.NetSendRecipient)
[void]$DataTable.Rows.Add('Parent',$Agent.Parent)
[void]$DataTable.Rows.Add('ParentCollection',$Agent.ParentCollection)
[void]$DataTable.Rows.Add('ReplaceAlertTokensEnabled',$Agent.ReplaceAlertTokensEnabled)
[void]$DataTable.Rows.Add('ReplaceAlertTokensEnabled',$Agent.ReplaceAlertTokensEnabled)
[void]$DataTable.Rows.Add('ServerVersion',$Agent.ServerVersion)
[void]$DataTable.Rows.Add('ServiceAccount',$Agent.ServiceAccount)
[void]$DataTable.Rows.Add('ServiceStartMode',$Agent.ServiceStartMode)
[void]$DataTable.Rows.Add('SqlAgentAutoStart',$Agent.SqlAgentAutoStart)
[void]$DataTable.Rows.Add('SqlAgentMailProfile',$Agent.SqlAgentMailProfile)
[void]$DataTable.Rows.Add('SqlAgentRestart',$Agent.SqlAgentRestart)
[void]$DataTable.Rows.Add('SqlServerRestart',$Agent.SqlServerRestart)
[void]$DataTable.Rows.Add('State',$Agent.State)
[void]$DataTable.Rows.Add('SysAdminOnly',$Agent.SysAdminOnly)
[void]$DataTable.Rows.Add('Urn',$Agent.Urn)
[void]$DataTable.Rows.Add('UserData',$Agent.UserData)
[void]$DataTable.Rows.Add('UserData',$Agent.UserData)
[void]$DataTable.Rows.Add('WriteOemErrorLog',$Agent.WriteOemErrorLog)

# Add Table-Formatted Setting/Values
$DataTable  | select-object -property Setting, Value | sort-object -property Setting| Format-Table | out-string | out-file $fullFileName -Encoding ascii -Append

# Add other Multi-Valued collections
$mystring =  "Job Categories: " + ($agent.JobCategories | select-object Parent, CategoryType, ID, Name, State | Format-Table | out-string)
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "AlertCategories: " + ($agent.AlertCategories | select-object ID, Name | Format-Table | out-string)
$mystring | out-file $fullFileName -Encoding ascii -Append

# Return to Initial Folder
set-location $BaseFolder
