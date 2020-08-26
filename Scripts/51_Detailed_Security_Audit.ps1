<#
.SYNOPSIS
    Gets SQL Server Security Information from the target server
    Permissions Tree by Login with SysAdmin equivalents
	
.DESCRIPTION

   
.EXAMPLE
    51_New_Security_Audit.ps1 localhost
	
.EXAMPLE
    51_New_Security_Audit.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	CSV File
	
.NOTES
	
	
.LINK
	
	
#>

[CmdletBinding()]
Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [string]$SQLInstance='localhost',
    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [string]$myuser,
    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [string]$mypass
)

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module -Name '.\sqltranscriptase.psm1' -ErrorAction Stop
}
catch
{
    Throw('Cant load required Powershell Modules')
}

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "51 - New Security Audit"
Write-Output("Server: [{0}]" -f $SQLInstance)

# Get the Domain I am in
$MyDomain = Get-ADDomain -Current LocalComputer
$ADDomainName = $MyDomain.NetBIOSName+'\'

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

# Create folder
[string]$BaseFolder = (get-location).path
$fullfolderPath = "$BaseFolder\$sqlinstance\51 - New Security Audit"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

# Prep Export Array
$ExportTable = New-Object System.Data.DataTable
$ExportTable.Columns.Add("Server","string") | out-null
$ExportTable.Columns.Add("Database","string") | out-null
$ExportTable.Columns.Add("SecurityPrincipal","string") | out-null
$ExportTable.Columns.Add("Rights","string") | out-null
$ExportTable.Columns.Add("IsSysAdmin","string") | out-null

# Export Security Information:
# 1) Get Databases

$sqlCMD1 = 
"
SELECT [Name] FROM master.sys.databases WHERE database_id >4 ORDER BY [name]
"


# Run Query 1
Write-Output "Get Databases..."
if ($serverauth -eq "win")
{
	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1
}
else
{
    $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1 -User $myuser -Password $mypass
}

# -----------------------
# iterate over each DB
# -----------------------
Write-Output "Processing Database Objects..."
foreach($sqlDatabase in $sqlresults1) 
{

    $DatabaseName = $sqlDatabase.Name

    # Skip MS System Databases
    if ($DatabaseName -in 'Model','TempDB','SSISDB','distribution') {continue}

    Write-Output("Processing Database: [{0}]" -f $DatabaseName)

    # 2) Login_to_User_Mappings
    $sqlCMD4 = "
    Use ["+ $DatabaseName + "];"+
    "
    SELECT 
	    sp.name AS 'Login', 
	    dp.name AS 'User',
        sp.type AS 'LoginType',
		sl.sysadmin AS 'IsSysAdmin'
    FROM 
    	sys.database_principals dp 
    INNER JOIN 
        sys.server_principals sp 
    ON 
        dp.sid = sp.sid 
	JOIN
		[master].[dbo].[syslogins] SL
	ON	
		sl.name = sp.name
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
    
    # Process Each Security Principal
    foreach($SecPrin in $sqlresults4)
    {
        $DBUser      = $SecPrin.User
        $LoginName   = $SecPrin.Login
        $LoginType   = $SecPrin.LoginType
        $IsSysAdmin  = $SecPrin.IsSysAdmin

        # NT AUTHORITY\Authenticated Users OverRide = All Active Directory Users
        #if ($LoginName -eq 'NT AUTHORITY\Authenticated Users')
        #{
        #    $LoginName = 'All Users'
        #}

        #Write-Output("Processing DBUser:[{0}], SVRLogin:[{1}], LoginType[{2}], IsSysAdmin:[{3}]" -f $DBUser, $LoginName, $LoginType, $IsSysAdmin)

        # Get Security Credentials
        $ReadWrite = $null

        # Member of db_datareader (R)
        $sqlCMD5 = "
        Use ["+ $DatabaseName + "];"+
        "
        SELECT 
            1
        FROM 
	        sysusers a 
        INNER JOIN 
		    sysmembers c 
        on 
		    a.uid = c.memberuid
        INNER JOIN 
		    sysusers b 
        ON 
		    c.groupuid = b.uid 
        WHERE 
		    a.name='$DBUser'
		    AND
		    b.name='db_datareader'
        "
    
        if ($serverauth -eq "win")
        {
	        $sqlresults5 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD5
        }
        else
        {
            $sqlresults5 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD5 -User $myuser -Password $mypass
        }

        # They have Read Access
        if ($sqlresults5 -ne $null)
        {
            $ReadWrite+='R'
        }

        # Member of db_datawriter (W)
        $sqlCMD6 = "
        Use ["+ $DatabaseName + "];"+
        "
        SELECT 
            1
        FROM 
	        sysusers a 
        INNER JOIN 
		    sysmembers c 
        on 
		    a.uid = c.memberuid
        INNER JOIN 
		    sysusers b 
        ON 
		    c.groupuid = b.uid 
        WHERE 
		    a.name='$DBUser'
		    AND
		    b.name='db_datawriter'
        "
    
        if ($serverauth -eq "win")
        {
	        $sqlresults6 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD6
        }
        else
        {
            $sqlresults6 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD6 -User $myuser -Password $mypass
        }

        
        # They have Write Access
        if ($sqlresults6 -ne $null)
        {
            $ReadWrite+='W'
        }

            
        # Member of db_owner (RW)
        $sqlCMD7= "
        Use ["+ $DatabaseName + "];"+
        "
        SELECT 
            1
        FROM 
	        sysusers a 
        INNER JOIN 
		    sysmembers c 
        on 
		    a.uid = c.memberuid
        INNER JOIN 
		    sysusers b 
        ON 
		    c.groupuid = b.uid 
        WHERE 
		    a.name='$DBUser'
		    AND
		    b.name='db_owner'
        "
    
        if ($serverauth -eq "win")
        {
	        $sqlresults7 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD7
        }
        else
        {
            $sqlresults7 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD7 -User $myuser -Password $mypass
        }

        # They have ReadWrite Access
        if ($sqlresults7 -ne $null)
        {
            $ReadWrite='RW'

        }

        # If Login is SysAdmin, override, they have everything
        if ($IsSysAdmin -eq 1)
        {
            $ReadWrite='RW'
        }


        # If the Server Login is an AD Security Group, resolve all names in the group and add them to our processing array
        if ($LoginType -eq 'G')
        {

            $ADGroupUsers = $null

            # Add the Group name itself
            [void]$ExportTable.Rows.Add( $SQLInstance,$DatabaseName,$LoginName,$ReadWrite,$IsSysAdmin)

            # Skip resolving [NT AUTHORITY\Authenticated Users] because its understood that its ALL Users
            if ($LoginName -eq 'NT AUTHORITY\Authenticated Users')
            {
                continue
            }
      
            # Skip resolving [NT AUTHORITY\ANONYMOUS LOGON] because its understood that its the UNKNOWN User (Kerberos Hopping issue)
            if ($LoginName -eq 'NT AUTHORITY\ANONYMOUS LOGON')
            {
                continue
            }
                    
            # Strip the Domain portion off the Login name and look for that Group name
            $GroupName = $LoginName.Replace($ADDomainName,'')

            # Get all Users of this AD Group
            try
            {
                $ADGroupUsers = Get-AdGroupMember -identity $GroupName -recursive  -ErrorAction Stop |Where {$_.objectClass -eq "user"}
            }
            catch
            {
                Write-Output('Error Getting ADGroup Member [{0}]' -f $LoginName)
                Write-Output('Error: [{0}]' -f $Error[0])
                continue
            }

            # Process individual Users in this Group
            foreach($ADUser in $ADGroupUsers)
            {   
                # Add Group Members to Array
                $Sam = $ADDomainName+$ADUser.SamAccountName                
                [void]$ExportTable.Rows.Add( $SQLInstance,$DatabaseName,$Sam,$ReadWrite,$IsSysAdmin)
            }
        }

        # Is Regular SQLUser or ADUser
        if ($LoginType -in ('S','U'))
        {            
             # Add to Array
            [void]$ExportTable.Rows.Add( $SQLInstance,$DatabaseName,$LoginName,$ReadWrite,$IsSysAdmin)
        }

    

    }  # Next DBUser

} # Next Database


# Add all Sysadmins
$sqlCMD10 = 
"
SELECT 
	l.[name] as 'Login', 
	p.type AS 'LoginType'
FROM 
	[master].[dbo].[syslogins] L
JOIN
	master.sys.server_principals P
ON 
	P.sid = L.sid
WHERE
	l.[name] NOT LIKE '##%'
	AND
	l.[name] NOT LIKE 'NT SERVICE\%'
	AND
	l.sysadmin=1
ORDER BY 
	l.[name]
"

# Run Query 10
Write-Output "Get Sysadmins..."
if ($serverauth -eq "win")
{
	$sqlresults10 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD10
}
else
{
    $sqlresults10 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD10 -User $myuser -Password $mypass
}

foreach($ServicePrincipal in $sqlresults10)
{

    $LoginName = $ServicePrincipal.Login
    $LoginType = $ServicePrincipal.LoginType

    # Add ServicePrincipal itself
    [void]$ExportTable.Rows.Add($SQLInstance,'*ALL*',$LoginName,'RW','1')

    # If a Group, resolve Members
    if ($LoginType -eq 'G')
    {
        
        $ADGroupUsers = $null       
                   
        # Strip the Domain portion off the Login name and look for that Group name
        $GroupName = $LoginName.Replace($ADDomainName,'')

        # Get all Users of this AD Group
        try
        {
            $ADGroupUsers = Get-AdGroupMember -identity $GroupName -recursive  -ErrorAction Stop | Where {$_.objectClass -eq "user"}

            # Process individual Users in the Group
            foreach($ADUser in $ADGroupUsers)
            {   
                # Add Group Members to Array
                $Sam = $ADDomainName+$ADUser.SamAccountName                
                [void]$ExportTable.Rows.Add($SQLInstance,'*ALL*',$Sam,'RW','1')
            }
        }
        catch
        {
            Write-Output('Error Getting ADGroup Member - Sysadmins [{0}]' -f $LoginName)
            Write-Output('Error: [{0}]' -f $Error[0])
            continue
        }

    }


}


#$ExportTable | ogv

# Export Array as CSV
$ServerFileName = $SQLInstance.Replace('\','_')
$ExportfileName = $fullfolderPath+'\Security_Audit_'+$ServerFileName+'.csv'
$ExportTable | sort @{Expression="IsSysAdmin";Descending=$true}, Database, SecurityPrincipal | export-csv $ExportfileName -notypeinformation -Force

#Start $ExportfileName

# Return To Base
set-location $BaseFolder