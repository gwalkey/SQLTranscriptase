<#
.SYNOPSIS
    Gets the Replication Configuration on the target server
	
.DESCRIPTION
   Writes the Replication Configuration out to the "18 - Replication" folder
      
.EXAMPLE
    18_Replication.ps1 localhost
	
.EXAMPLE
    18_Replication.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

    # DMVs
    https://msdn.microsoft.com/en-us/library/ms176053.aspx

    # Stored Procs
    https://msdn.microsoft.com/en-us/library/ms174364.aspx

    --- Objects
    Distribution Database
    Distributor
    Publisher
    Subscriber
    LogReader
    SnapshotAgent
    Push Subscription
    Pull Subscription
    Article

    -------------
    Log Shipping:
    -------------
    https://msdn.microsoft.com/en-us/library/ms187103.aspx
    https://msdn.microsoft.com/en-us/library/ms175106.aspx
    log_shipping_monitor_alert
    log_shipping_monitor_error_detail
    log_shipping_monitor_history_detail
    log_shipping_monitor_primary
    log_shipping_monitor_secondary
    log_shipping_primary_databases
    log_shipping_primary_secondaries --
    log_shipping_secondary
    log_shipping_secondary_databases

    Setup Steps:
    On Primary:
    exec master.dbo.sp_add_log_shipping_primary_database 
    exec sp_add_schedule "LSBackupSchedule_"
    exec msdb.dbo.sp_attach_schedule
    exec msdb.dbo.sp_update_job @enabled = 1
    EXEC master.dbo.sp_add_log_shipping_alert_job 
    EXEC master.dbo.sp_add_log_shipping_primary_secondary 

    Setup Steps:
    On Secondary:
    EXEC master.dbo.sp_add_log_shipping_secondary_primary 
    EXEC msdb.dbo.sp_add_schedule "DefaultCopyJobSchedule"
    EXEC msdb.dbo.sp_attach_schedule 
    EXEC msdb.dbo.sp_add_schedule "DefaultRestoreJobSchedule"
    EXEC msdb.dbo.sp_attach_schedule 
    EXEC @LS_Add_RetCode2 = master.dbo.sp_add_log_shipping_secondary_database 
    EXEC msdb.dbo.sp_update_job @Enabled = 1

    
    ------------
    Replication:
    ------------
    1) Transactional
    2) Snapshot
    3) Merge
    4) Peer-to-Peer Transactional
    5) Mirroring

    # Setup includes a Distribution Database on all 3 Actors:
    # Distributor
    # Publisher
    # Subscriber

    # TSQL Check for Replication installed
    select count(*) from sys.databases where name = 'Distribution'
    select * from sys.databases where is_published = 1 or is_subscribed = 1 or is_merge_published = 1 or is_distributor = 1


    Mirroring:
    https://msdn.microsoft.com/en-us/library/ms189852.aspx
    select * from sys.database_mirroring where mirroring_guid is not null - Main Query
    sys.database_mirroring_witnesses 
    sys.dm_db_mirroring_connections
    sys.dm_db_mirroring_auto_page_repair
    sys.database_mirroring_endpoints 


    AlwaysOn AGs:
    https://msdn.microsoft.com/en-us/library/ff878265.aspx
    sys.dm_hadr_auto_page_repair
    sys.dm_hadr_cluster
    sys.dm_hadr_cluster_members
    sys.dm_hadr_cluster_networks
    sys.dm_hadr_instance_node_map
    sys.dm_hadr_availability_group_states
    sys.dm_hadr_availability_replica_cluster_nodes
    sys.dm_hadr_availability_replica_cluster_states
    sys.dm_hadr_availability_replica_states
    sys.dm_hadr_database_replica_cluster_states
    sys.dm_hadr_database_replica_states    
    sys.dm_hadr_name_id_map
    sys.dm_hadr_cluster
    sys.dm_tcp_listener_states
    sys.dm_hadr_cluster_members
    sys.fn_hadr_backup_is_preferred_replica

    sys.availability_databases_cluster
    sys.availability_groups
    sys.availability_groups_cluster
    sys.availability_group_listeners
    sys.availability_group_listener_ip_addresses
    sys.availability_read_only_routing_lists    
    sys.availability_replicas
    


	
.LINK

	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "18 - Replication"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./18_Replication.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Load Additional Assemblies
add-type -AssemblyName "Microsoft.SqlServer.Rmo, version=12.0.0.0, Culture=Neutral, PublicKeyToken=89845dcd8080cc91"
add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, version=12.0.0.0, Culture=Neutral, PublicKeyToken=89845dcd8080cc91";
#add-type -AssemblyName "Microsoft.SqlServer.Replication, version=12.0.0.0, Culture=Neutral, PublicKeyToken=89845dcd8080cc91";
#[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Replication")


# Server connection check
try
{
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
    	$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
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
    Write-Host -f red "$SQLInstance appears offline - Try Windows Auth?"
    Set-Location $BaseFolder
	exit
}

# Set Local Vars
$server = $SQLInstance


if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
}

# Create RMO Objects
$RepInstanceObject = New-Object "Microsoft.SqlServer.Replication.ReplicationServer" $server
$RepInstanceStatus = New-Object "Microsoft.SqlServer.Replication.ReplicationMonitor" $server


# Output Folder
Write-Output "$SQLInstance - Replication"
$Replication_path  = "$BaseFolder\$SQLInstance\18 - Replication\"
if(!(test-path -path $Replication_path))
{
    mkdir $Replication_path | Out-Null	
}


# Check for Existence of Replication Databases
if ($RepInstanceObject.ReplicationDatabases.Count -eq 0) 
{
    write-output "I found NO replicated databases on $server"
    exit
}
else
{
    Write-Output ("{0} Replication Databases found on {1}" -f $RepInstanceObject.ReplicationDatabases.Count, $server)
}


# Look for Trans or Merge Objects
[int] $Count_Tran_Pub = 0
[int] $Count_Merge_Pub = 0

foreach($replicateddatabase in $RepInstanceObject.ReplicationDatabases) 
{
        $Count_Tran_Pub = $Count_Tran_Pub + $replicateddatabase.TransPublications.Count
        $Count_Merge_Pub = $Count_Merge_Pub + $replicateddatabase.MergePublications.Count
}

if (($Count_Tran_Pub + $Count_Merge_Pub) -eq 0) 
{

    Write-Output "I Found NO Publications on $server"
    exit
}


# Output to file
Write-Host "[+]Snapshot Agent Current Status" -BackgroundColor Green -ForegroundColor Black
foreach($SMonitorServer in $RepInstanceStatus.EnumSnapshotAgents())
{
    foreach($SMon in $SMonitorServer.Tables)
    {
        foreach($SnapshotAgent in $SMon | SELECT dbname,name,status,publisher,publisher_db,publication,subscriber,subscriber_db,starttime,time,duration,comments)
        {

        Write-Host "dbname :" $SnapshotAgent.dbname
        Write-Host "Snapshot Agent :" $SnapshotAgent.name -ForegroundColor Green
        write-host "status :" $SnapshotAgent.status
        write-host "publisher :" $SnapshotAgent.publisher
        write-host "publisher_db :" $SnapshotAgent.publisher_db
        write-host "publication :" $SnapshotAgent.publication
        write-host "subscriber :" $SnapshotAgent.subscriber
        write-host "subscriber_db :" $SnapshotAgent.subscriber_db
        write-host "starttime :" $SnapshotAgent.starttime
        write-host "time :" $SnapshotAgent.time
        write-host "duration :" $SnapshotAgent.duration
        write-host "comments :" $SnapshotAgent.comments -ForegroundColor Green
        write-host "*********************************************************************"
        }
    }
}

# Script Out
$myoutputfile = $Replication_path+$SMonitorServer+".sql"
$SMonitorServer | out-file -FilePath $myoutputfile -append -encoding ascii -width 500



# Return Home
set-location $BaseFolder



