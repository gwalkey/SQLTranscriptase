<#
.SYNOPSIS
    Gets the SQL Agent Alerts
	
.DESCRIPTION
   Writes the SQL Agent Alerts out to the "04 - Agent Alerts" folder, Agent_Alerts.sql file
   One file for all Alerts
   
.EXAMPLE
    04_Agent_Alerts.ps1 localhost
	
.EXAMPLE
    04_Agent_Alerts.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "04 - Agent Alerts"
Write-Output "Server $SQLInstance"

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

# Get Major Version Only
[int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

switch ($ver)
{
    7  {Write-Output "SQL Server 7"}
    8  {Write-Output "SQL Server 2000"}
    9  {Write-Output "SQL Server 2005"}
    10 {Write-Output "SQL Server 2008/R2"}
    11 {Write-Output "SQL Server 2012"}
    12 {Write-Output "SQL Server 2014"}
    13 {Write-Output "SQL Server 2016"}
    14 {Write-Output "SQL Server 2017"}
	15 {Write-Output "SQL Server 2019"}
}



 # Get the Alerts Themselves
$sqlCMD2 = 
"
SELECT 

AlertText = 
CASE 
	WHEN tsha.job_id='00000000-0000-0000-0000-000000000000' AND tsha.performance_condition IS NOT NULL THEN
		'EXEC msdb.dbo.sp_add_alert '+char(13)+char(10)+
		' @name=N'+CHAR(39)+tsha.NAME+CHAR(39)+char(13)+char(10)+
		',@message_id='+CONVERT(VARCHAR(6),tsha.message_id)+char(13)+char(10)+
		',@severity='+CONVERT(VARCHAR(10),tsha.severity)+char(13)+char(10)+
		',@enabled='+CONVERT(VARCHAR(10),tsha.[enabled])+char(13)+char(10)+
		',@delay_between_responses='+convert(varchar(10),tsha.delay_between_responses)+char(13)+char(10)+
		',@include_event_description_in='+CONVERT(VARCHAR(5),tsha.include_event_description)+char(13)+char(10)+
		',@performance_condition='+char(39)+COALESCE(tsha.performance_condition,'')+char(39)+char(13)+char(10)

	WHEN tsha.job_id='00000000-0000-0000-0000-000000000000' AND tsha.performance_condition IS null THEN
	'EXEC msdb.dbo.sp_add_alert '+char(13)+char(10)+
	' @name=N'+CHAR(39)+tsha.NAME+CHAR(39)+char(13)+char(10)+
	',@message_id='+CONVERT(VARCHAR(6),tsha.message_id)+char(13)+char(10)+
	',@severity='+CONVERT(VARCHAR(10),tsha.severity)+char(13)+char(10)+
	',@enabled='+CONVERT(VARCHAR(10),tsha.[enabled])+char(13)+char(10)+
	',@delay_between_responses='+convert(varchar(10),tsha.delay_between_responses)+char(13)+char(10)+
	',@include_event_description_in='+CONVERT(VARCHAR(5),tsha.include_event_description)+char(13)+char(10)

	WHEN tsha.job_id<>'00000000-0000-0000-0000-000000000000' AND tsha.performance_condition IS NOT NULL THEN
		'EXEC msdb.dbo.sp_add_alert '+char(13)+char(10)+
		' @name=N'+CHAR(39)+tsha.NAME+CHAR(39)+char(13)+char(10)+
		',@message_id='+CONVERT(VARCHAR(6),tsha.message_id)+char(13)+char(10)+
		',@severity='+CONVERT(VARCHAR(10),tsha.severity)+char(13)+char(10)+
		',@enabled='+CONVERT(VARCHAR(10),tsha.[enabled])+char(13)+char(10)+
		',@delay_between_responses='+convert(varchar(10),tsha.delay_between_responses)+char(13)+char(10)+
		',@include_event_description_in='+CONVERT(VARCHAR(5),tsha.include_event_description)+char(13)+char(10)+
		',@job_Name=N'+char(39)+sj.[name]+char(39)+char(13)+char(10)+
		',@performance_condition='+char(39)+COALESCE(tsha.performance_condition,'')+char(39)+char(13)+char(10)

	WHEN tsha.job_id<>'00000000-0000-0000-0000-000000000000' AND tsha.performance_condition IS NULL THEN
		'EXEC msdb.dbo.sp_add_alert '+char(13)+char(10)+
		' @name=N'+CHAR(39)+tsha.NAME+CHAR(39)+char(13)+char(10)+
		',@message_id='+CONVERT(VARCHAR(6),tsha.message_id)+char(13)+char(10)+
		',@severity='+CONVERT(VARCHAR(10),tsha.severity)+char(13)+char(10)+
		',@enabled='+CONVERT(VARCHAR(10),tsha.[enabled])+char(13)+char(10)+
		',@delay_between_responses='+convert(varchar(10),tsha.delay_between_responses)+char(13)+char(10)+
		',@include_event_description_in='+CONVERT(VARCHAR(5),tsha.include_event_description)+char(13)+char(10)+
		',@job_Name=N'+char(39)+sj.[name]+char(39)+char(13)+char(10)
	END
FROM 
	msdb.dbo.sysalerts tsha
LEFT JOIN
	[msdb].[dbo].[sysjobs] sj
ON
	tsha.job_id = sj.job_id
"


# Get the Notifications for Each Alert (Typically Email)
$sqlCMD3 = 
"
select 
    NotifyText =
	'EXEC msdb.dbo.sp_add_notification '+char(13)+char(10)+
	' @alert_name =N'+CHAR(39)+A.[name]+CHAR(39)+CHAR(13)+CHAR(10)+
	' ,@operator_name = N'+CHAR(39)+O.[name]+CHAR(39)+CHAR(13)+CHAR(10)+	
	' ,@notification_method= 1'
from 
	[msdb].[dbo].[sysalerts] a
inner join 
	[msdb].[dbo].[sysnotifications] n
ON
	a.id = n.alert_id
inner join
	[msdb].[dbo].[sysoperators] o
on 
	n.operator_id = o.id
"

$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Alerts"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


	
# Get ALerts
if ($serverauth -eq 'sql')
{
	Write-Output "Using SQL Auth"
    
    # Alerts
    $results1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database 'master' -SQLExec $sqlCMD2 -User $myuser -Password $mypass
    
    if ($results1 -eq $null)
    {
        Write-Output "No Agent Alerts Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alerts Found.txt"
        Set-Location $BaseFolder
        exit
    }

    New-Item "$fullfolderPath\Agent_Alerts.sql" -type file -force  |Out-Null
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Foreach ($row in $results1)
    {
        $row.AlertText | out-file "$fullfolderPath\Agent_Alerts.sql" -Encoding ascii -Append
    }

    # Notifications
    Write-Output ("Exported: {0} Alerts" -f $results1.count)

	$results2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database 'master' -SQLExec $sqlCMD3 -User $myuser -Password $mypass

    if ($results2 -eq $null)
    {
        Write-Output "No Agent Alert Notifications Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alert Notifications Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Export Alert Notifications
    New-Item "$fullfolderPath\Agent_Alert_Notifications.sql" -type file -force  |Out-Null
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding Ascii
    Foreach ($row in $results2)
    {
        $row.NotifyText | out-file "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding ascii -Append
    }

    Write-Output ("Exported: {0} Alert Notifications" -f $results2.count)
}
else
{
	Write-Output "Using Windows Auth"
    
    # Alerts
    $results1 =  ConnectWinAuth -SQLInstance $SQLInstance -Database 'master' -SQLExec $sqlCMD2

    if ($results1 -eq $null)
    {
        Write-Output "No Agent Alerts Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alerts Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Export
    New-Item "$fullfolderPath\Agent_Alerts.sql" -type file -force  |Out-Null
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alerts.sql" -Encoding Ascii
    Foreach ($row in $results1)
    {
        $row.AlertText | out-file "$fullfolderPath\Agent_Alerts.sql" -Encoding ascii -Append
    }
    Write-Output ("{0} Alerts Exported" -f $results1.count)

    # Notifications
    $results2 = $results1 =  ConnectWinAuth -SQLInstance $SQLInstance -Database 'master' -SQLExec $sqlCMD3

    if ($results2 -eq $null)
    {
        Write-Output "No Agent Alert Notifications Found on $SQLInstance"        
        echo null > "$BaseFolder\$SQLInstance\04 - No Agent Alert Notifications Found.txt"
        Set-Location $BaseFolder
        exit
    }

    # Export
    New-Item "$fullfolderPath\Agent_Alert_Notifications.sql" -type file -force  |Out-Null
    Add-Content -Value "USE MSDB `r`nGO `r`n" -Path "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding Ascii
    Foreach ($row in $results2)
    {
        $row.NotifyText+"`r`n" | out-file "$fullfolderPath\Agent_Alert_Notifications.sql" -Encoding ascii -Append
    }

    Write-Output ("{0} Alert Notifications Exported" -f $results2.count)

}

# Return To Base
set-location $BaseFolder


