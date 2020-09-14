<#
.SYNOPSIS
    Gets all Server and Database Permissions for all Logins
	
.DESCRIPTION
      
.EXAMPLE
    50_Security_Tree.ps1 localhost
	
.EXAMPLE
    50_Security_Tree.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES


.LINK
	https://github.com/gwalkey
	
	
#>

[CmdletBinding()]
Param(
  [string]$SQLInstance="localhost",
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
Write-Host  -f Yellow -b Black "50 - Security Tree"
Write-Output("Server: [{0}]" -f $SQLInstance)


# --------
# Startup
# --------
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


# Create base output folder
$output_path = "$BaseFolder\$SQLInstance\50 - Security Tree\"
if(!(test-path -path $output_path))
{
    mkdir $output_path | Out-Null
}


# ----------------------------------------
# Get Public Fixed Server Role Permissions
# ----------------------------------------
$myPFSRfile = $output_path+"Public_Fixed_Server_Role.txt"
"`r`nPublic Fixed Server Role permissions:" | out-file $myPFSRfile -Append

$sqlCMD1=
"
SELECT 
    sp.state_desc, 
    sp.permission_name, 
    sp.class_desc, 
    sp.major_id, 
    sp.minor_id, 
    e.[name] as [endpointname],
    l.[name]
FROM sys.server_permissions AS sp
JOIN sys.server_principals AS l
    ON sp.grantee_principal_id = l.principal_id
LEFT JOIN sys.endpoints AS e
    ON sp.major_id = e.endpoint_id
WHERE l.name = 'public';
"


if ($serverauth -eq "win")
{
    $ServerPerms = ConnectWinAuth -SQLExec $sqlCMD1 -SQLInstance $SQLInstance -Database "master"
}
else
{
    $ServerPerms = ConnectSQLAuth -SQLExec $sqlCMD1 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
}
    
$statement =''
foreach ($perm in $ServerPerms)
{
    if ($perm.class_desc -eq 'ENDPOINT')
    {
        $statement = '     '+$Perm.state_desc +' '+$Perm.Permission_name+' on '+$Perm.Class_desc+"::"+$perm.endpointname+' to '+$perm.name
    }
    else
    {
        $statement = '     '+$Perm.state_desc +' '+$Perm.Permission_name+' to '+$Perm.Name
    }
    $statement | out-file $myPFSRfile -Append

}

# Get all online databases
$sqlCMD2 = 
"
SELECT
	*
FROM
	sys.databases
WHERE 
    [state]=0 and [name]<>'tempdb'
order by 
    [name]
"

if ($serverauth -eq "win")
{
    $Databases = ConnectWinAuth $sqlCMD2 -SQLInstance $SQLInstance -Database "master"
}
else
{
    $Databases = ConnectSQLAuth $sqlCMD2 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
}

# Get Logins to Process
$sqlCMD3=
"
SELECT 
	[NAME],
	[type],
	[default_database_name],
	[is_disabled]
FROM 
	sys.server_principals
WHERE 
	[name] NOT LIKE 'NT Service%' AND 
	[name] NOT LIKE ('NT AUTHORITY%') AND
	LEFT([NAME],2)<>'##' AND
    [name] NOT IN ('BUILTIN\Administrators','distributor_admin') AND
	[TYPE] <>'R'
ORDER BY 
	1
"

if ($serverauth -eq "win")
{
    $logins = ConnectWinAuth -SQLExec $sqlCMD3 -SQLInstance $SQLInstance -Database "master"
}
else
{
    $logins = ConnectSQLAuth -SQLExec $sqlCMD3 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
}


foreach($myLogin in $logins)
{
    # Create Output File
    $myLoginName = $fixedDBName = $myLogin.name.replace('\','_')
    $myoutputfile = $output_path+$myLoginName+".txt"
    Write-Output("Login [{0}]" -f $myLogin.name) 
    Write-Output("Login [{0}]" -f $myLogin.name) | out-file $myoutputfile -Append    
    Write-Output("Default Database: [{0}]" -f $myLogin.default_database_name) | out-file $myoutputfile -Append
    if ($myLogin.is_disabled -eq '1')
    {
        Write-Output("Login is disabled") | out-file $myoutputfile -Append
    }
    
    $login = $myLogin.name

    # --------------------------------------
    # Get Explicit Server-Level Permissions
    # --------------------------------------
    "`r`nServer-Level Permissions:" | out-file $myoutputfile -Append

    $sqlCMD4 = 
    "
    SELECT 
    	x.[name],
    	x.[type_desc],	
    	x.[type],
    	p.[state_desc] AS 'Action',
    	p.[permission_name] AS 'Perm',
    	p.[class_desc] AS 'On'
    FROM 
    	sys.server_permissions p
    JOIN 
    	sys.server_principals x
    ON 
    	p.grantee_principal_id=x.principal_id
    WHERE 
        x.[name] = '$Login'
    "

    if ($serverauth -eq "win")
    {
        $ServerPerms = ConnectWinAuth -SQLExec $sqlCMD4 -SQLInstance $SQLInstance -Database "master"
    }
    else
    {
        $ServerPerms = ConnectSQLAuth -SQLExec $sqlCMD4 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
    }

    foreach ($perm in $ServerPerms)
    {
        $statement = '     '+$Perm.action +' '+$Perm.Perm+' to '+$Perm.Name
        $statement | out-file $myoutputfile -Append

    }
    

    # ---------------------------------
    # Get Fixed Server Role Permissions
    # ---------------------------------
    "`r`nFixed Server Role Permissions:" | out-file $myoutputfile -Append

    $sqlCMD5=
    "
    SELECT 	
	    sRole.name AS [Server_Role_Name]
    FROM sys.server_role_members AS sRo  
    JOIN sys.server_principals AS sPrinc  
        ON sRo.member_principal_id = sPrinc.principal_id  
    JOIN sys.server_principals AS sRole  
        ON sRo.role_principal_id = sRole.principal_id
    WHERE 
    	sPrinc.name='$login'
    "
    
    if ($serverauth -eq "win")
    {
        $FSRPerms = ConnectWinAuth -SQLExec $sqlCMD5 -SQLInstance $SQLInstance -Database "master"
    }
    else
    {
        $FSRPerms = ConnectSQLAuth -SQLExec $sqlCMD5 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
    }

    $statement=''
    foreach($FSR in $FSRPerms)
    {
        switch ($FSR.Server_Role_Name)
        {            
            'securityadmin' {$statement+= '     '+$login+" is a member of the [Securityadmin] Fixed Server Role`r`n"}
            'serveradmin'   {$statement+= '     '+$login+" is a member of the [Serveradmin] Fixed Server Role`r`n"}
            'setupadmin'    {$statement+= '     '+$login+" is a member of the [Setupadmin] Fixed Server Role`r`n"}
            'processadmin'  {$statement+= '     '+$login+" is a member of the [Processadmin] Fixed Server Role`r`n"}
            'diskadmin'     {$statement+= '     '+$login+" is a member of the [Diskadmin] Fixed Server Role`r`n"}
            'dbcreator'     {$statement+= '     '+$login+" is a member of the [DBcreator] Fixed Server Role`r`n"}
            'bulkadmin'     {$statement+= '     '+$login+" is a member of the [Bulkadmin] Fixed Server Role`r`n"}
            'sysadmin'      {$statement+= '     '+$login+" is a member of the [Sysadmin] Fixed Server Role`r`n"}
        }
    }

    $statement | out-file $myoutputfile -Append
    


    

    # ----------------------------------
    # Get Permissions for Each Database
    # ----------------------------------

    Write-Output("`r`nDatabase Permissions:") | out-file $myoutputfile -Append
    foreach($database in $Databases)
    {
        $DBName = $database.name

        # Get the Login-to-User mapping first
        $sqlCMD6=
        "
        SELECT 
	        susers.[name] AS [ServerLogin],
	        users.[name] AS [DBUser]
        from 
	        sys.server_principals susers
        JOIN
	        sys.database_principals users 
        on 
	        susers.sid = users.sid
        where
            susers.[name] = '$Login'
        "

        if ($serverauth -eq "win")
        {
            $LoginToUserMap = ConnectWinAuth -SQLExec $sqlCMD6 -SQLInstance $SQLInstance -Database $DBName
        }
        else
        {
            $LoginToUserMap = ConnectSQLAuth -SQLExec $sqlCMD6 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass
        }

        # Skip the Database if there is no Login to User Mapping
        if ($LoginToUserMap -eq $null) {continue}

        $DBUser = $LoginToUserMap.DBUser

        Write-Output("[{0}]" -f $DBName) | out-file $myoutputfile -Append
        Write-Output("    Login-to-User mapping:[{1}]-->[{2}]" -f $DBName, $LoginToUserMap.ServerLogin, $LoginToUserMap.DBUser) | out-file $myoutputfile -Append


        # Get database-scoped permissions at database level
        #"Database-scoped permissions at the database level:" | out-file $myoutputfile -Append

        $sqlCMD7=
        "
        SELECT
            perms.class_desc as [PermissionClass],
            perms.permission_name AS Permission,
            type_desc AS [PrincipalType],
            prin.name as Principal
        FROM 
            sys.database_permissions perms
        JOIN
            sys.database_principals prin
        ON
            perms.grantee_principal_id = prin.principal_id
        WHERE 
            grantee_principal_id NOT IN (DATABASE_PRINCIPAL_ID('guest'), DATABASE_PRINCIPAL_ID('public')) 
            AND perms.class = 0
            AND prin.name = '$DBUser'
        "
        if ($serverauth -eq "win")
        {
            $DBScopedPerms = ConnectWinAuth -SQLExec $sqlCMD7 -SQLInstance $SQLInstance -Database $DBName
        }
        else
        {
            $DBScopedPerms = ConnectSQLAuth -SQLExec $sqlCMD7 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass
        }
        
        # Script out
        $statement =''
        foreach ($perm in $DBScopedPerms)
        {
            $statement = '     GRANT '+$Perm.Permission+' to ['+$perm.principal+']'
            $statement | out-file $myoutputfile -Append

        }
        


        # Get high impact database-scoped permissions at object level
        #"Database-scoped permissions at the object level:" | out-file $myoutputfile -Append
        $sqlCMD8=
        "
        SELECT 
	        perms.class_desc as [PermissionClass], 
	        OBJECT_SCHEMA_NAME(major_id) as [Schema], 
	        OBJECT_NAME(major_id) as [Object], 
	        perms.permission_name AS Permission, 
	        type_desc AS [PrincipalType], 
	        prin.name as Principal
        FROM
	        sys.database_permissions perms
        JOIN
	        sys.database_principals prin
        ON
	        perms.grantee_principal_id = prin.principal_id 
        WHERE 
	        grantee_principal_id NOT IN (DATABASE_PRINCIPAL_ID('guest'), DATABASE_PRINCIPAL_ID('public')) 
            AND perms.class = 1
            AND prin.name = '$DBUser'
        "

        if ($serverauth -eq "win")
        {
            $DBObjectPerms = ConnectWinAuth -SQLExec $sqlCMD8 -SQLInstance $SQLInstance -Database $DBName
        }
        else
        {
            $DBObjectPerms = ConnectSQLAuth -SQLExec $sqlCMD8 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass
        }

        $statement =''
        foreach ($perm in $DBObjectPerms)
        {
            $statement = '     GRANT '+$Perm.Permission+' on ['+$perm.schema+']['+$perm.Object+'] to ['+$perm.principal+']'
            $statement | out-file $myoutputfile -Append

        }
        
        # Get Database Role Membership
        #"`r`nFixed Database Role Memberships:" | out-file $myoutputfile -Append
        $sqlCMD9=
        "
        SELECT 
	        dRole.name AS [DBRole]	
        FROM 
            sys.database_role_members AS dRo  
        JOIN 
            sys.database_principals AS dPrinc  
        ON 
            dRo.member_principal_id = dPrinc.principal_id  
        JOIN 
            sys.database_principals AS dRole  
        ON 
            dRo.role_principal_id = dRole.principal_id  
        WHERE
    	    dPrinc.name='$DBUser'
        "
    
        if ($serverauth -eq "win")
        {
            $DBRoleMemberships = ConnectWinAuth -SQLExec $sqlCMD9 -SQLInstance $SQLInstance -Database $DBName
        }
        else
        {
            $DBRoleMemberships = ConnectSQLAuth -SQLExec $sqlCMD9 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass
        }

        $statement=''
        foreach($DBRole in $DBRoleMemberships)
        {
            $myRole = $DBRole.DBRole
            switch ($myRole)
            {            
                'db_owner'           {
                                        '     ['+$DBUser+"] is a member of the [db_owner] Fixed Database Role" | out-file $myoutputfile -Append
                                     }

                'db_securityadmin'   {
                                        '     ['+$DBUser+"] is a member of the [db_securityadmin] Fixed Database Role" | out-file $myoutputfile -Append
                                     }

                'db_accessadmin'     {
                                        '     ['+$DBUser+"] is a member of the [db_accessadmin] Fixed Database Role" | out-file $myoutputfile -Append
                                     }

                'db_backupoperator'  {
                                        '     ['+$DBUser+"] is a member of the [db_backupoperator] Fixed Database Role" | out-file $myoutputfile -Append
                                     }

                'db_ddladmin'        {
                                        '     ['+$DBUser+"] is a member of the [db_ddladmin] Fixed Database Role" | out-file $myoutputfile -Append
                                        '          GRANT ALTER ANY ASSEMBLY'+$DBName+' to ['+$DBUser+']' | out-file $myoutputfile -Append
                                        
                                     }

                'db_datawriter'      {                                        
                                        '     ['+$DBUser+"] is a member of the [db_datawriter] Fixed Database Role" | out-file $myoutputfile -Append
                                        '          GRANT INSERT on DATABASE::'+$DBName+' to ['+$DBUser+']' | out-file $myoutputfile -Append
                                        '          GRANT DELETE on DATABASE::'+$DBName+' to ['+$DBUser+']' | out-file $myoutputfile -Append
                                        '          GRANT UPDATE on DATABASE::'+$DBName+' to ['+$DBUser+']' | out-file $myoutputfile -Append                                        
                                     }

                'db_datareader'      {                                        
                                        '     ['+$DBUser+"] is a member of the [db_datareader] Fixed Database Role" | out-file $myoutputfile -Append
                                        '          GRANT SELECT on DATABASE::'+$DBName+' to '+$DBUser  | out-file $myoutputfile -Append                                        
                                     }

                'db_denydatawriter'  {
                                        '     ['+$DBUser+"] is a member of the [db_denydatawriter] Fixed Database Role" | out-file $myoutputfile -Append                                        
                                     }

                'db_denydatareader'  {
                                        '     ['+$DBUser+"] is a member of the [db_denydatareader] Fixed Database Role" | out-file $myoutputfile -Append                                        
                                     }

                default              {
                                        '     ['+$DBUser+"] is a member of the [$myRole] Fixed Database Role" | out-file $myoutputfile -Append                                        
                                     }
            }
        }

        
        

    } # Next Database
} # Next Login





# Return To Base
set-location $BaseFolder

