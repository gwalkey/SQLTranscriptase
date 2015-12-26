<#
.SYNOPSIS
    Gets the SQL Agent Schedules
	
.DESCRIPTION
    Writes the SQL Sgent Job Schedules out to the "04 - Agent Schedules" folder, "Agent_Schedules.sql" file
	
.EXAMPLE
    04_Agent_Schedules.ps1 localhost
	
.EXAMPLE
    04_Agent_Schedules.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "04 - Agent Schedules"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Schedules.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    exit
}

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Working
Write-Output "Server $SQLInstance"


$sql = 
"

SELECT     
	'Exec msdb.dbo.sp_add_schedule '+
	' @schedule_name='+char(39)+[name]+char(39)+
	' ,@enabled=' + CASE [enabled] WHEN 1 THEN '1' WHEN 0 THEN '0' END+
	' ,@freq_type=' + convert(varchar(4),[freq_type])+
    ' ,@freq_interval=' +convert(varchar(3),[freq_interval])+
	' ,@freq_subday_type='+convert(varchar(3),[freq_subday_type])+
	' ,@freq_subday_interval='+convert(varchar(3),[freq_subday_interval])+
	' ,@freq_relative_interval='+convert(varchar(3),[freq_relative_interval])+
    ' ,@freq_recurrence_Factor='+convert(varchar(3),[freq_recurrence_factor])+
	' ,@active_start_date='+convert(varchar(8),[active_start_date])+
	' ,@active_end_date='+convert(varchar(8),[active_end_date])+
	' ,@active_start_time='+convert(varchar(8),[active_start_time])+
	' ,@active_end_time='+convert(varchar(8),[active_end_time])
FROM [msdb].[dbo].[sysschedules]
"

$fullfolderPath = "$BaseFolder\$SQLInstance\04 - Agent Schedules"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

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

# Turn off default error handler
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'	

if ($serverauth -eq "win")
{
	Write-Output "Using Windows Auth"

	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$outdata = $DataSet.Tables[0].Rows


    #$outdata = Invoke-SqlCmd -query $sql -Server $SQLInstance
}
else
{
    Write-Output "Using SQL Auth"
    
    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$outdata = $DataSet.Tables[0].Rows
    
    #$outdata = Invoke-SqlCmd -query $sql  -Server $SQLInstance –Username $myuser –Password $mypass    
}

if ($outdata -eq $null )
{
    Write-Output "No Agent Schedules Found on $SQLInstance"
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Schedules Found.txt"
    Set-Location $BaseFolder
    exit
}
    
# Reset default PS error handler
$ErrorActionPreference = $old_ErrorActionPreference 
    
New-Item "$fullfolderPath\Agent_Schedules.sql" -type file -force |Out-Null
$Outdata| Select column1 -ExpandProperty column1 | out-file "$fullfolderPath\Agent_Schedules.sql" -Encoding ascii -Append -Width 10000

Write-Output ("{0} Agent Schedules Exported"  -f $outdata.count)


# ---------------------------
# Create Visual Job Schedule
# ---------------------------

<#
System Tables:

sysjobs
https://msdn.microsoft.com/en-us/library/ms189817.aspx

sysschedules
https://msdn.microsoft.com/en-us/library/ms178644.aspx

sysjobschedules
https://msdn.microsoft.com/en-us/library/ms188924.aspx


In sysschedules:
Freq_Type
1 = One time only
4 = Daily
8 = Weekly
16 = Monthly
32 = Monthly, relative to freq_interval
64 = Runs when the SQL Server Agent service starts
128 = Runs when the computer is idle

freq_interval
1 (once) - freq_interval is unused (0)
4 (daily) - Every freq_interval days
8 (weekly)- freq_interval is one or more of the following:
            1 = Sunday
            2 = Monday
            4 = Tuesday
            8 = Wednesday
            16 = Thursday
            32 = Friday
            64 = Saturday
16 (monthly) - On the freq_interval day of the month
32 (monthly, relative)- freq_interval is one of the following:
            1 = Sunday
            2 = Monday
            3 = Tuesday
            4 = Wednesday
            5 = Thursday
            6 = Friday
            7 = Saturday
            8 = Day
            9 = Weekday
            10 = Weekend day
64 (starts when SQL Server Agent service starts)- freq_interval is unused (0)
128 (runs when computer is idle) - freq_interval is unused (0)

freq_subday_type
1-At the specified time
2-Seconds
4-Minutes
8-Hours

freq_subday_interval
Number of freq_subday_type periods to occur between each execution of the job

freq_relative_interval
When freq_interval occurs in each month, if freq_interval is 32 (monthly relative). Can be one of the following values:
            0 = freq_relative_interval is unused
            1 = First
            2 = Second
            4 = Third
            8 = Fourth
            16 = Last

freq_recurrence_factor
Number of weeks or months between the scheduled execution of a job. 
freq_recurrence_factor is used only if freq_type is 8, 16, or 32. 
If this column contains 0, freq_recurrence_factor is unused


In sysjobschedules: "The sysjobschedules table refreshes every 20 minutes"
job_id
next_run_date
next_run_time

In sysjobs:
job_id
name
enabled

#>

$sql2 = 
"



declare @AgentSked TABLE(
[Sked] nvarchar(128) NOT NULL,
[Sked_Enabled] int not null,
[Schedule_uid] uniqueidentifier not null,
[Job] nvarchar(128) NOT NULL,
[Job_Enabled] int not null,
[Frequency] varchar(45) not null,
[Freq_Interval] varchar(45) not null,
[Freq_SubDay_Type] varchar(25) not null,
[Freq_SubDay_Interval] int not null,
[StartDate] varchar(10) not null,
[StartTime] varchar(8) not null,
[StartHour] int not null,
[OriginalStartHour] int not null,
[EndHour] int not null,
[00Z] varchar(1) not null,
[01Z] varchar(1) not null,
[02Z] varchar(1) not null,
[03Z] varchar(1) not null,
[04Z] varchar(1) not null,
[05Z] varchar(1) not null,
[06Z] varchar(1) not null,
[07Z] varchar(1) not null,
[08Z] varchar(1) not null,
[09Z] varchar(1) not null,
[10Z] varchar(1) not null,
[11Z] varchar(1) not null,
[12Z] varchar(1) not null,
[13Z] varchar(1) not null,
[14Z] varchar(1) not null,
[15Z] varchar(1) not null,
[16Z] varchar(1) not null,
[17Z] varchar(1) not null,
[18Z] varchar(1) not null,
[19Z] varchar(1) not null,
[20Z] varchar(1) not null,
[21Z] varchar(1) not null,
[22Z] varchar(1) not null,
[23Z] varchar(1) not null
)

INSERT into @AgentSked
SELECT   
k.[name],
k.[enabled] as 'Sked_Enabled',
k.[Schedule_uid],
j.[name],
j.[enabled] as 'Job Enabled',
case [freq_type]
	when 1 then 'One Shot'
	when 4 then 'Daily'
	when 8 then 'Weekly'
	when 16 then 'Monthly'
	when 32 then 'Monthly, relative to freq_interval'
	when 64 then 'At Agent Startup'
	when 128 then 'When Idle'
end as 'Frequency',
case [freq_type]
	when 0 then 'Once'
	when 1 then	'Daily'
	when 4 then 'Every '+convert(varchar,[freq_interval])+' Days'
	when 8 then 'Weekly on '+
		case when [freq_interval] & 1=1 then 'Sun ' else '' end+
		case when [freq_interval] & 2=2 then 'Mon ' else '' end+
		case when [freq_interval] & 4=4 then 'Tue ' else '' end+
		case when [freq_interval] & 8=8 then 'Wed ' else '' end+
		case when [freq_interval] & 16=16 then 'Thu ' else '' end+
		case when [freq_interval] & 32=32 then 'Fri ' else '' end+
		case when [freq_interval] & 64=64 then 'Sat ' else '' end
	when 16 then 'Monthly on the '+convert(varchar,[freq_interval])+' day of the Month'
	when 32 then 'Monthly Relative to '+
		case [freq_interval]
			when 1 then 'Sun'
			when 2 then 'Mon'
			when 3 then 'Tue'
			when 4 then 'Wed'
			when 5 then 'Thu'
			when 6 then 'Fri'
			when 7 then 'Sat'
			when 8 then 'Day'
			when 9 then 'WeekDays'
			when 10 then 'Weekends'
		end 
	when 64  then 'When SQL Agent Starts'
	when 128 then 'When Idle'
end as 'Freq Interval',
case [freq_subday_type] 
	when 0 then ''
	when 1 then 'At StartTime'
	when 2 then 'Every '+ convert(varchar,[freq_subday_interval]) + ' Seconds'
	when 4 then 'Every '+ convert(varchar,[freq_subday_interval]) + ' Minutes'
	when 8 then 'Every '+ convert(varchar,[freq_subday_interval]) + ' Hours'
end as 'Freq_Subday_Type',
[Freq_SubDay_Interval],
substring(convert(char,k.active_start_date),1,4) + '-'+substring(convert(char,k.active_start_date),5,2) +'-'+substring(convert(char,k.active_start_date),7,2) as 'StartDate',
case LEN(convert(varchar,k.active_start_time))
	when 1 then '00:00:00'
	when 2 then '00:00:00'
	when 3 then '00:00:00'
	when 4 then '00:'+SUBSTRING(convert(varchar,k.active_start_time),1,2)+':'+SUBSTRING(convert(varchar,k.active_start_time),3,2)
	when 5 then '0'+SUBSTRING(convert(varchar,k.active_start_time),1,1)+':'+SUBSTRING(convert(varchar,k.active_start_time),2,2)+':'+SUBSTRING(convert(varchar,k.active_start_time),4,2)
	when 6 then SUBSTRING(convert(varchar,k.active_start_time),1,2)+':'+SUBSTRING(convert(varchar,k.active_start_time),3,2)+':'+SUBSTRING(convert(varchar,k.active_start_time),5,2)
end as 'StartTime',

case LEN(convert(varchar,k.active_start_time))
	when 1 then
		'0'+convert(char,k.active_start_time)
	when 3 then
		'00'
	when 4 then
		'00'
	when 5 then
		'0'+SUBSTRING(convert(varchar,k.active_start_time),1,1)
	when 6 then
		SUBSTRING(convert(varchar,k.active_start_time),1,2)
end as 'StartHour',
0 as 'OriginalStartHour',
case LEN(convert(varchar,k.active_end_time))
	when 1 then
		'0'+convert(char,k.active_end_time)
	when 3 then
		'00'
	when 4 then
		'00'
	when 5 then
		'0'+SUBSTRING(convert(varchar,k.active_end_time),1,1)
	when 6 then
		SUBSTRING(convert(varchar,k.active_end_time),1,2)
end as 'EndHour',
[00Z] = '',
[01Z] = '',
[02Z] = '',
[03Z] = '',
[04Z] = '',
[05Z] = '',
[06Z] = '',
[07Z] = '',
[08Z] = '',
[09Z] = '',
[10Z] = '',
[11Z] = '',
[12Z] = '',
[13Z] = '',
[14Z] = '',
[15Z] = '',
[16Z] = '',
[17Z] = '',
[18Z] = '',
[19Z] = '',
[20Z] = '',
[21Z] = '',
[22Z] = '',
[23Z] = ''
FROM [msdb].[dbo].[sysschedules] k
inner join [msdb].[dbo].[sysjobschedules] b
on k.schedule_id = b.schedule_id
inner join [msdb].[dbo].[sysjobs] j
on b.job_id = j.job_id


--- Pass 1 - Mark all 'When SQL Agent Starts' jobs as Hour24 to sort low
update t
set StartHour = 99 
from @AgentSked t
where t.[Frequency]='At Agent Startup'

--- Save Original StartHour for cosmetic reasons
update t 
set OriginalStartHour = StartHour 
from @AgentSked t


--- Pass 2 - Mark all 'At StartTime' or 'One Shot' jobs as just that one hour of the day
update t
set [00Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 0

update t
set [01Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 1

update t
set [02Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 2

update t
set [03Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 3

update t
set [04Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 4

update t
set [05Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 5

update t
set [06Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 6

update t
set [07Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 7

update t
set [08Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 8

update t
set [09Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 9

update t
set [10Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 10

update t
set [11Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 11

update t
set [12Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 12

update t
set [13Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 13

update t
set [14Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 14

update t
set [15Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 15

update t
set [16Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 16

update t
set [17Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 17

update t
set [18Z] = 'x'
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 18

update t
set [19Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 19

update t
set [20Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 20

update t
set [21Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 21

update t
set [22Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 22

update t
set [23Z] = 'x' 
from @AgentSked t
where (t.[Freq_SubDay_Type]='At StartTime' or t.[Frequency]='One Shot') and t.StartHour = 23


--- Pass 3 - Get all Jobs that run only Every Hour
update t
set 
t.[00Z]='x',
t.[01Z]='x',
t.[02Z]='x',
t.[03Z]='x',
t.[04Z]='x',
t.[05Z]='x',
t.[06Z]='x',
t.[07Z]='x',
t.[08Z]='x',
t.[09Z]='x',
t.[10Z]='x',
t.[11Z]='x',
t.[12Z]='x',
t.[13Z]='x',
t.[14Z]='x',
t.[15Z]='x',
t.[16Z]='x',
t.[17Z]='x',
t.[18Z]='x',
t.[19Z]='x',
t.[20Z]='x',
t.[21Z]='x',
t.[22Z]='x',
t.[23Z]='x'
FROM @AgentSked t
where t.[Freq_SubDay_Type]='Every 1 Hours'



--- Pass 3 - Get all Jobs that run 'Every X Minutes', 'Every X Seconds'
update t
set 
t.[00Z]='X',
t.[01Z]='X',
t.[02Z]='X',
t.[03Z]='X',
t.[04Z]='X',
t.[05Z]='X',
t.[06Z]='X',
t.[07Z]='X',
t.[08Z]='X',
t.[09Z]='X',
t.[10Z]='X',
t.[11Z]='X',
t.[12Z]='X',
t.[13Z]='X',
t.[14Z]='X',
t.[15Z]='X',
t.[16Z]='X',
t.[17Z]='X',
t.[18Z]='X',
t.[19Z]='X',
t.[20Z]='X',
t.[21Z]='X',
t.[22Z]='X',
t.[23Z]='X'
FROM @AgentSked t
where t.[Freq_SubDay_Type] like '%Minutes' or t.[Freq_SubDay_Type] like '%Seconds'



--- Pass 4 - Get all Jobs that run Every X Hours
declare @x integer
set @x = 0
while @x>=0 and @x<=23
begin

update t
set t.[00Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=0

update t
set t.[01Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=1 and t.EndHour>=1

update t
set t.[02Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=2 and t.EndHour>=2

update t
set t.[03Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=3 and t.EndHour>=3

update t
set t.[04Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=4 and t.EndHour>=4

update t
set t.[05Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=5 and t.EndHour>=5

update t
set t.[06Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=6 and t.EndHour>=6

update t
set t.[07Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=7 and t.EndHour>=7

update t
set t.[08Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=8 and t.EndHour>=8

update t
set t.[09Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=9 and t.EndHour>=9

update t
set t.[10Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=10 and t.EndHour>=10

update t
set t.[11Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=11 and t.EndHour>=11

update t
set t.[12Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=12 and t.EndHour>=12

update t
set t.[13Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=13 and t.EndHour>=13

update t
set t.[14Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=14 and t.EndHour>=14

update t
set t.[15Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=15 and t.EndHour>=15
update t
set t.[16Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=16 and t.EndHour>=16

update t
set t.[17Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=17 and t.EndHour>=17

update t
set t.[18Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=18 and t.EndHour>=18

update t
set t.[19Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=19 and t.EndHour>=19

update t
set t.[20Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=20 and t.EndHour>=20

update t
set t.[21Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=21 and t.EndHour>=21

update t
set t.[22Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=22 and t.EndHour>=22

update t
set t.[23Z] = 'x'
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours' and StartHour=23 and t.EndHour=23

--- Move Their starttime by their interval
update t 
set t.[starthour] = t.starthour+t.Freq_SubDay_Interval
from @AgentSked t
where t.Freq_SubDay_Type like 'Every %% Hours' and [Freq_SubDay_Type]<>'Every 1 Hours'

set @x = @x + 1
end


--- Restore Original StartHour for cosmetic reasons
update t 
set StartHour = OriginalStartHour 
from @AgentSked t

select * from @AgentSked 
where job_enabled = 1
order by StartHour, Sked, job


"

# Get the Agent Job Sked from SQL
if ($serverauth -eq "win")
{
	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql2
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$LiveSkeds = $DataSet.Tables[0].Rows

    #$LiveSkeds =  Invoke-Sqlcmd -MaxCharLength 100000000 -ServerInstance $SQLInstance -Query $sql2
}
else
{
    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sql2
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$LiveSkeds = $DataSet.Tables[0].Rows


    #$LiveSkeds =  Invoke-Sqlcmd -MaxCharLength 100000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $sql2
}



# Create some CSS for help in column formatting during HTML exports
$myCSS = 
"
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
# CSS file
if(!(test-path -path "$fullfolderPath\HTMLReport.css"))
{
    $myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii    
}


$RunTime = Get-date
# Export the Enabled Job Schedules to HTML
$LiveSkeds | select Sked, Sked_Enabled, Job, Job_Enabled, Frequency, Freq_Interval, Freq_SubDay_Type, Freq_SubDay_Interval, StartDate, StartTime, StartHour, `
00Z, 01Z, 02Z, 03Z, 04Z, 05Z, 06Z, 07Z, 08Z, 09Z, 10Z, 11Z, 12Z, 13Z, 14Z, 15Z, 16Z, 17Z, 18Z, 19Z, 20Z, 21Z, 22Z, 23Z `
| ConvertTo-Html  -PreContent "<h1>$SqlInstance</H1><H2>SQL Agent Job Schedules</h2>" -CSSUri "HtmlReport.css" -PostContent "<h3>Ran on : $RunTime</h3>"| Set-Content "$fullfolderPath\AgentJobSchedules.html"

# Export the Enabled Job Schedules to CSV
$LiveSkeds | select Sked, Sked_Enabled, Job, Job_Enabled, Frequency, Freq_Interval, Freq_SubDay_Type, Freq_SubDay_Interval, StartDate, StartTime, StartHour, `
00Z, 01Z, 02Z, 03Z, 04Z, 05Z, 06Z, 07Z, 08Z, 09Z, 10Z, 11Z, 12Z, 13Z, 14Z, 15Z, 16Z, 17Z, 18Z, 19Z, 20Z, 21Z, 22Z, 23Z `
| export-CSV -LiteralPath "$fullfolderPath\AgentJobSchedules.csv"


Write-Output ("{0} Agent Jobs Exported"  -f $LiveSkeds.count)

# Return to Base
set-location $BaseFolder


