<#
.SYNOPSIS
  Gets the numberof Virtual Log File Blocks
	
.DESCRIPTION
  Gets the numberof Virtual Log File Blocks
   
.EXAMPLE
    33_VLF_Count.ps1 localhost
	
.EXAMPLE
    33_VLF_Count.ps1.ps1 server01 sa password

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
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "33 - Virtual Log File Count"
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


# New UP SQL SMO Object
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
$output_path = "$BaseFolder\$SQLInstance\33 - VLF Count\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

	
# GET VLF Count
$sqlCMD1 = 
"
--dbcc loginfo()
--variables to hold each 'iteration'  
declare @query varchar(100)  
declare @dbname sysname  
declare @vlfs int  
  
--table variable used to 'loop' over databases  
declare @databases table (dbname sysname)  
insert into @databases  
--only choose online databases  
select name from sys.databases where state = 0  
  
--table variable to hold results  
declare @vlfcounts table  
    (dbname sysname,  
    vlfcount int)  
 
--table variable to capture DBCC loginfo output  
--changes in the output of DBCC loginfo from SQL2012 mean we have to determine the version 
 
declare @MajorVersion tinyint  
set @MajorVersion = LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))-1) 
 
if @MajorVersion < 11 -- pre-SQL2012 
begin 
    declare @dbccloginfo table  
    (  
        fileid tinyint,  
        file_size bigint,  
        start_offset bigint,  
        fseqno int,  
        [status] tinyint,  
        parity tinyint,  
        create_lsn numeric(25,0)  
    )  
  
    while exists(select top 1 dbname from @databases)  
    begin  
  
        set @dbname = (select top 1 dbname from @databases)  
        set @query = 'dbcc loginfo (' + '''' + @dbname + ''') '  
  
        insert into @dbccloginfo  
        exec (@query)  
  
        set @vlfs = @@rowcount  
  
        insert @vlfcounts  
        values(@dbname, @vlfs)  
  
        delete from @databases where dbname = @dbname  
  
    end --while 
end 
else 
begin 
    declare @dbccloginfo2012 table  
    (  
        RecoveryUnitId int, 
        fileid tinyint,  
        file_size bigint,  
        start_offset bigint,  
        fseqno int,  
        [status] tinyint,  
        parity tinyint,  
        create_lsn numeric(25,0)  
    )  
  
    while exists(select top 1 dbname from @databases)  
    begin  
  
        set @dbname = (select top 1 dbname from @databases)  
        set @query = 'dbcc loginfo (' + '''' + @dbname + ''') '  
  
        insert into @dbccloginfo2012  
        exec (@query)  
  
        set @vlfs = @@rowcount  
  
        insert @vlfcounts  
        values(@dbname, @vlfs)  
  
        delete from @databases where dbname = @dbname  
  
    end --while 
end 
  
--output the full list  
select dbname, vlfcount  
from @vlfcounts  
order by 1


"


# Run Query 1
Write-Output "Get VLF Count, Order by Database..."

if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1 -User $myuser -Password $mypass
}

# Use HTML Fragments
$sqlCMD2 = 
"
--dbcc loginfo()
--variables to hold each 'iteration'  
declare @query varchar(100)  
declare @dbname sysname  
declare @vlfs int  
  
--table variable used to 'loop' over databases  
declare @databases table (dbname sysname)  
insert into @databases  
--only choose online databases  
select name from sys.databases where state = 0  
  
--table variable to hold results  
declare @vlfcounts table  
    (dbname sysname,  
    vlfcount int)  
  
 
 
--table variable to capture DBCC loginfo output  
--changes in the output of DBCC loginfo from SQL2012 mean we have to determine the version 
 
declare @MajorVersion tinyint  
set @MajorVersion = LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))-1) 
 
if @MajorVersion < 11 -- pre-SQL2012 
begin 
    declare @dbccloginfo table  
    (  
        fileid tinyint,  
        file_size bigint,  
        start_offset bigint,  
        fseqno int,  
        [status] tinyint,  
        parity tinyint,  
        create_lsn numeric(25,0)  
    )  
  
    while exists(select top 1 dbname from @databases)  
    begin  
  
        set @dbname = (select top 1 dbname from @databases)  
        set @query = 'dbcc loginfo (' + '''' + @dbname + ''') '  
  
        insert into @dbccloginfo  
        exec (@query)  
  
        set @vlfs = @@rowcount  
  
        insert @vlfcounts  
        values(@dbname, @vlfs)  
  
        delete from @databases where dbname = @dbname  
  
    end --while 
end 
else 
begin 
    declare @dbccloginfo2012 table  
    (  
        RecoveryUnitId int, 
        fileid tinyint,  
        file_size bigint,  
        start_offset bigint,  
        fseqno int,  
        [status] tinyint,  
        parity tinyint,  
        create_lsn numeric(25,0)  
    )  
  
    while exists(select top 1 dbname from @databases)  
    begin  
  
        set @dbname = (select top 1 dbname from @databases)  
        set @query = 'dbcc loginfo (' + '''' + @dbname + ''') '  
  
        insert into @dbccloginfo2012  
        exec (@query)  
  
        set @vlfs = @@rowcount  
  
        insert @vlfcounts  
        values(@dbname, @vlfs)  
  
        delete from @databases where dbname = @dbname  
  
    end --while 
end 
  
--output the full list  
select dbname, vlfcount  
from @vlfcounts  
order by 2 desc

"


# Run Query 2
Write-Output "Get VLF Count, Order by count..."
if ($serverauth -eq "win")
{
	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}

# Use HTML Fragments for multiple tables and inline CSS
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

$RunTime = Get-date


$myoutputfile4 = $output_path+"VLF_Count.html"
$myHtml1 = $sqlresults1 | select DBName, vlfcount| ConvertTo-Html -Fragment -as table  -PreContent "<h3>VLF Count on Server $SQLINstance</h3> <h3>Name Order</h3>"
$myHtml2 = $sqlresults2 | select DBName, vlfcount| ConvertTo-Html -Fragment -as table -PreContent "<h3>Count Order</h3>"
Convertto-Html -head $head -Body "$myHtml1<br>$myHtml2" -Title "VLF Count Summary" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

set-location $BaseFolder
