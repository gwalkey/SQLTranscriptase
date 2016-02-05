USE MSDB 
GO 

EXEC msdb.dbo.sp_add_alert 
 @name=N'AppDomain eviction due to memory pressure'
,@message_id=10311
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 1205 - Transaction Deadlock'
,@message_id=1205
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 14151 - Fulltext Catalog Not Setup on Replicated Table'
,@message_id=14151
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 14157 - Replication Subscription Dropped'
,@message_id=14157
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17053 - LogWriter OS Error - Device not ready'
,@message_id=17053
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17120 - Could not spawn a signal thread'
,@message_id=17120
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17173 - Trace Flag Ignored During Startup'
,@message_id=17173
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17187 - Login Failed - Server Starting up'
,@message_id=17187
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17189 - Failed to spawn a new thread'
,@message_id=17189
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17204 - Could not open file'
,@message_id=17204
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17207 - OS could not open file'
,@message_id=17207
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17806 - SSPI Handshake Failed during connection attempt'
,@message_id=17806
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17883 - Non-Yielding Worker Process'
,@message_id=17883
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17884 - Non-Dispatched Worker Process'
,@message_id=17884
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17887 - IO Completion Listener not yielding'
,@message_id=17887
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17888 - All Schedulers deadlocked waiting on non-yielding workers'
,@message_id=17888
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17890 - Most SQL process memory paged out'
,@message_id=17890
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 17891 - Resource Monitor Worker non-yielding'
,@message_id=17891
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 18056 - Login Failed - Server Shutting Down'
,@message_id=18056
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 18204 - Backup Failed'
,@message_id=18204
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 18401 - Server in script-upgrade mode'
,@message_id=18401
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 18452 - Login from an untrusted Domain cannot be used with Windows Auth'
,@message_id=18452
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 18456 - Login Failed'
,@message_id=18456
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3041 - Backup Failed'
,@message_id=3041
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3203 - CRC Error on File Read'
,@message_id=3203
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3314 - Log Read Errors Encountered'
,@message_id=3314
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3401 - Recovery Errors during transaction rollback'
,@message_id=3401
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3410 - Deferred Transactions exist for offline Filegroup'
,@message_id=3410
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3414 - Error during recovery - Database Cannot restart'
,@message_id=3414
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3422 - DB shutdown due to error in routine'
,@message_id=3422
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3449 - Server Shutdown Initiated to recover System Database'
,@message_id=3449
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3452 - DB Recovery detected identity value inconsistency'
,@message_id=3452
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3619 - Log full while writing checkpoint'
,@message_id=3619
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3620 - Auto checkpointing disabled due to full log'
,@message_id=3620
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 3959 - Version Store full'
,@message_id=3959
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5029 - DB Log rebuilt, Tranactional consistency lost, RESTORE chain broken'
,@message_id=5029
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5105 - File Activation Error'
,@message_id=5105
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5120 - Unable to open the physical file'
,@message_id=5120
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5144 - File autogrow cancelled or timed out'
,@message_id=5144
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5145 - File Autogrow excessive duration'
,@message_id=5145
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 5182 - New Log File Created'
,@message_id=5182
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 547 - DRI Constraint Violation'
,@message_id=547
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 601 - Could not continue scan with NOLOCK due to data movement'
,@message_id=601
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 674 - Exception occurred in destructor of RowsetNewSS'
,@message_id=674
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 701 -  Insufficient system memory to run this query'
,@message_id=701
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 708 - Virtual Memory exhausted'
,@message_id=708
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 806 - Disk block read error'
,@message_id=806
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 823 - IO Device Error'
,@message_id=823
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 824 - IO Logical Consistency Error'
,@message_id=824
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 825 - IO Subsystem Doomed'
,@message_id=825
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 833 - Slow IO Detected'
,@message_id=833
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 845 - Buffer Latch Timeout'
,@message_id=845
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 8539 - DTC Transaction forced commit'
,@message_id=8539
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 8540 - DTC Transaction forced rollback'
,@message_id=8540
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 9001 - DB Log not available'
,@message_id=9001
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 9002 - TranLog File is Full'
,@message_id=9002
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 9645 - Service Broker Manager Offline'
,@message_id=9645
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Error Number 9954 - Failed to communicate with FullText Service'
,@message_id=9954
,@severity=0
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Lock Wait Time (ms)'
,@message_id=0
,@severity=0
,@enabled=0
,@delay_between_responses=0
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 014 - Insufficient Permission'
,@message_id=0
,@severity=14
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 015 - SQL Syntax Error'
,@message_id=0
,@severity=15
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 016 - Miscellaneous User Error'
,@message_id=0
,@severity=16
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 017 - Insufficient Resources'
,@message_id=0
,@severity=17
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 018 - Nonfatal Internal SQL Engine Error'
,@message_id=0
,@severity=18
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 019 - Fatal Error in Resource - SQL Limit reached'
,@message_id=0
,@severity=19
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 020 - Fatal Error in Current Database Process'
,@message_id=0
,@severity=20
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 021 - Fatal Error in all Database Processes'
,@message_id=0
,@severity=21
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 022 - Table Integrity Suspect'
,@message_id=0
,@severity=22
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 023 - Database Integrity Suspect'
,@message_id=0
,@severity=23
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 024 - Fatal Hardware Error'
,@message_id=0
,@severity=24
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'

EXEC msdb.dbo.sp_add_alert 
 @name=N'Severity 025 - Fatal Error'
,@message_id=0
,@severity=25
,@enabled=1
,@delay_between_responses=60
,@include_event_description_in=1
,@job_id=N'00000000-0000-0000-0000-000000000000'


