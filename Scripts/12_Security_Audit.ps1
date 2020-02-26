<#
.SYNOPSIS
    Gets SQL Server Security Information from the target server
	
.DESCRIPTION
   Writes out the results of 5 SQL Queries to a sub folder of the Server Name 
   One HTML file for each Query
   
.EXAMPLE
    12_Security_Audit.ps1 localhost
	
.EXAMPLE
    12_Security_Audit.ps1 server01 sa password

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
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "12 - Security Audit"
Write-Output("Server: [{0}]" -f $SQLInstance)

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

[int]$ver = GetSQLNumericalVersion $myver


# Set Local Vars
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


# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\12 - Security Audit"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}


# HTML CSS
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


# Export Security Information:
# 1) SQL Logins

$sqlCMD1 = 
"
--- Server Logins
--- Q1 Logins, Default DB,  Auth Type, and FixedServerRole Memberships
SELECT 
	name as 'Login', 
	dbname as 'DefaultDB',
	[language],  
	CONVERT(CHAR(10),CASE denylogin WHEN 1 THEN 'X' ELSE '--' END) AS IsDenied, 
	CONVERT(CHAR(10),CASE isntname WHEN 1 THEN 'X' ELSE '--' END) AS IsWinAuthentication, 
	CONVERT(CHAR(10),CASE isntgroup WHEN 1 THEN 'X' ELSE '--' END) AS IsWinGroup, 
	Createdate,
	Updatedate, 
	CONVERT(VARCHAR(2000), 
	CASE sysadmin WHEN 1 THEN 'sysadmin,' ELSE '' END + 
	CASE securityadmin WHEN 1 THEN 'securityadmin,' ELSE '' END + 
	CASE serveradmin WHEN 1 THEN 'serveradmin,' ELSE '' END + 
	CASE setupadmin WHEN 1 THEN 'setupadmin,' ELSE '' END + 
	CASE processadmin WHEN 1 THEN 'processadmin,' ELSE '' END + 
	CASE diskadmin WHEN 1 THEN 'diskadmin,' ELSE '' END + 
	CASE dbcreator WHEN 1 THEN 'dbcreator,' ELSE '' END + 
	CASE bulkadmin WHEN 1 THEN 'bulkadmin' ELSE '' END ) AS ServerRoles,
	CASE sysadmin WHEN 1 THEN 'Y' ELSE ' ' END as IsSysAdmin
INTO 
	#syslogins 
FROM 
	master..syslogins WITH (nolock) 

UPDATE 
	#syslogins 
SET 
	ServerRoles = SUBSTRING(ServerRoles,1,LEN(ServerRoles)-1) 
WHERE 
	SUBSTRING(ServerRoles,LEN(ServerRoles),1) = ',' 

UPDATE 
	#syslogins SET ServerRoles = '--' 
WHERE 
	LTRIM(RTRIM(ServerRoles)) = '' 

select * from #syslogins order by IsSysAdmin desc, Login

drop table #syslogins

"


# Run Query 1
Write-Output "Server Logins..."
if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1 -User $myuser -Password $mypass
}

# Script out Logins
$RunTime = Get-date
$myoutputfile4 = $FullFolderPath+"\1_Server_Logins.html"
$myHtml1 = $sqlresults1 | select Login, DefaultDB, language, IsDenied, IsWinAuthentication, IsWinGroup, CreateDate, UpdateDate, ServerRoles, IsSysAdmin | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Server Logins</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Server Logins" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4



# 2) Server Login to Database User Global Mapping Listing
Write-Output "Server Login to Database User Global Mapping Listing..."

$SQLCMD2 = "


create table #Login2UserMapping (
	login_name nvarchar(255),
	Database_Name nvarchar(255),
    Database_User nvarchar(255),
	Default_Schema nvarchar(255)
)

DECLARE @Database_Name nvarchar(255)
DECLARE @sqlcmd nvarchar(max)

DECLARE db_cursor CURSOR Fast_Forward
FOR SELECT name from sys.databases where [name] not like 'Sharepoint%' and [name] not like '%.%'  and [state]=0
OPEN db_cursor

FETCH NEXT FROM db_cursor INTO @Database_Name
WHILE (@@fetch_status =0)
BEGIN
	set @sqlcmd = 'Use ['+@Database_Name+']; '
	set @sqlcmd=@sqlcmd + '
	insert into #Login2UserMapping
	SELECT 
	sp.name AS ''Login_Name'', 
	db_name() AS ''Database_Name'',
	dp.name AS ''Database_User'',
	coalesce(dp.default_schema_name,'' '') as ''Default_Schema''
    FROM 
    sys.database_principals dp 
    INNER JOIN sys.server_principals sp 
    ON dp.sid = sp.sid 
    WHERE sp.is_disabled<>1
    ORDER BY 
    sp.name, 
    dp.name;
	'
	exec (@sqlcmd)

    FETCH NEXT FROM db_cursor INTO @Database_Name
END
/*close and deallocate cursor*/
CLOSE db_cursor
DEALLOCATE db_cursor

select * from #Login2UserMapping order by 1,2
drop table #Login2UserMapping

"

# Run Query 2
if ($serverauth -eq "win")
{
	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}

# Write Out Rows
$RunTime = Get-date
$myoutputfile4 = $FullFolderPath+"\2_Server_Logins_to_Database_User_Mappings.html"
$myHtml1 = $sqlresults2 | select  Login_Name, Database_Name, Database_User, Default_Schema | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Server Login to Database User Mapping</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Server Login to Database User Mapping" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

set-location $BaseFolder

# -----------------------
# iterate over each DB
# -----------------------
Write-Output "Processing Database Objects..."
foreach($sqlDatabase in $srv.databases) 
{
    # Skip Certain System Databases - change to your liking
    if ($sqlDatabase.Name -in 'Model','TempDB','SSISDB','distribution','ReportServer','ReportServerTempDB') {continue}

    # Create Output Folders - One Per DataBase
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$fullfolderPath\Databases\$fixedDBname"
    
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null	
    }

    # Skip Offline Databases (SMO still enumerates them, but we cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    $sqlDatabase.Name
    $dbName = $sqlDatabase.Name

    # 1) Orphaned Users
    $sqlCMD3 = 
    "
    use [$dbname];

    SELECT
        u.name AS 'DBUser',
		COALESCE(l.name,'-none-') AS 'ServerLogin',
        u.type_desc, 
        u.type
    FROM
        sys.database_principals u 
    LEFT JOIN 
        sys.server_principals l ON u.sid = l.sid 
    WHERE 
        l.sid IS NULL 
        AND u.type NOT IN ('A', 'R', 'C') -- not a db./app. role or certificate
        AND u.principal_id > 4 -- not dbo, guest or INFORMATION_SCHEMA
        AND u.name NOT LIKE '%DataCollector%' 
        AND u.name NOT LIKE 'mdw%'
    ORDER BY
        1
    "

    # Run SQL
    if ($serverauth -eq "win")
    {
	    $sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3
    }
    else
    {
        $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -User $myuser -Password $mypass
    }

    $myoutputfile4 = $output_path+"\1_Orphaned Users.html"
    $myHtml1 = $sqlresults3 | select  DBUser, ServerLogin, Type_desc, type | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Orphaned Users in [$dbname]</h2>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Orphaned Users in $dbname" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

    
    # 2) Login_to_User_Mappings
    $sqlCMD4 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    sp.name AS 'Login', 
	    dp.name AS 'User' 
    FROM 
    	sys.database_principals dp 
    INNER JOIN sys.server_principals sp 
        ON dp.sid = sp.sid 
    ORDER BY 
    	sp.name, 
    	dp.name;
    "

    # Run SQL
    if ($serverauth -eq "win")
    {
	    $sqlresults4 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4
    }
    else
    {
        $sqlresults4 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4 -User $myuser -Password $mypass
    }
    $myoutputfile4 = $output_path+"\2_Login_to_User_Mapping.html"
    $myHtml1 = $sqlresults4 | select  Login, User | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Login-to-User Mappings in [$dbname]</h2>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Login-to-User Mappings" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

    set-location $BaseFolder


    # 3) Roles per User
    $sqlCMD5 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
        a.name AS User_name,
	    b.name AS Role_name	   
    FROM 
    sysusers a 
    INNER JOIN sysmembers c 
    	on a.uid = c.memberuid
    INNER JOIN sysusers b 
    	ON c.groupuid = b.uid 
    	WHERE a.name <> 'dbo' 
    order by 
    	1,2
    "
    
    if ($serverauth -eq "win")
    {
	    $sqlresults5 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD5
    }
    else
    {
        $sqlresults5 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD5 -User $myuser -Password $mypass
    }
        
    $myoutputfile4 = $output_path+"\3_Roles_Per_User.html"
    $myHtml1 = $sqlresults5 | select User_Name,Role_Name | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Roles Per User in [$dbname]</h2>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Roles Per User" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

    set-location $BaseFolder

    # 4) Database-Level Permissions
    $sqlCMD6 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    usr.name as 'User', 
	    CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END as 'Operation', 
	    perm.permission_name,  
	    CASE WHEN perm.state <> 'W' THEN '--' ELSE 'X' END AS IsGrantOption 
    FROM 
    	sys.database_permissions AS perm 
    INNER JOIN 
    	sys.database_principals AS usr 
    ON 
    	perm.grantee_principal_id = usr.principal_id 
    WHERE 
    	perm.major_id = 0 
    ORDER BY 
    	usr.name, perm.permission_name ASC, perm.state_desc ASC
    "
    # Run SQL
    if ($serverauth -eq "win")
    {
	    $sqlresults6 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD6
    }
    else
    {
        $sqlresults6 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD6 -User $myuser -Password $mypass
    }

    $myoutputfile4 = $output_path+"\4_DB-Level_Permissions.html"
    $myHtml1 = $sqlresults6 | select User, Operation, permission_name, IsGrantOption | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>DataBase-Level Permissions in [$dbname]</h2>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "DataBase-Level Permissions" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4
    set-location $BaseFolder

    # 5) Individual Database-Level Object Permissions
    $sqlCMD7 = "
    Use ["+ $sqlDatabase.Name + "];"+
    "
    SELECT 
	    usr.name AS 'User', 
	    CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END AS PermType, 
	    perm.permission_name,
	    USER_NAME(obj.schema_id) AS SchemaName, 
	    obj.name AS ObjectName, 
	    CASE obj.Type  
		    WHEN 'U' THEN 'Table'
		    WHEN 'V' THEN 'View'
		    WHEN 'P' THEN 'Stored Proc'
		    WHEN 'FN' THEN 'Function'
	    ELSE obj.Type END AS ObjectType, 
	    CASE WHEN cl.column_id IS NULL THEN '--' ELSE cl.name END AS ColumnName, 
	    CASE WHEN perm.state = 'W' THEN 'X' ELSE '--' END AS IsGrantOption 
    FROM
	    sys.database_permissions AS perm 
    INNER JOIN sys.objects AS obj 
	    ON perm.major_id = obj.[object_id] 
    INNER JOIN sys.database_principals AS usr 
	    ON perm.grantee_principal_id = usr.principal_id 
    LEFT JOIN sys.columns AS cl 
	    ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id 
    WHERE 
	    obj.Type <> 'S'
    ORDER BY 
	    usr.name, perm.state_desc ASC, perm.permission_name ASC

    "
    
	# Run SQL
    if ($serverauth -eq "win")
    {
	    $sqlresults7 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD7
    }
    else
    {
        $sqlresults7 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD7 -User $myuser -Password $mypass
    }

    $myoutputfile4 = $output_path+"\5_Object_Permissions.html"
    $myHtml1 = $sqlresults7 | select User, PermType, permission_name, SchemaName, ObjectName, ObjectType, ColumnName, IsGrantOption | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Object-Level Permissions in [$dbname]</h2>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Object-Level Permissions" -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4    

    set-location $BaseFolder
        
}

# Return To Base
set-location $BaseFolder