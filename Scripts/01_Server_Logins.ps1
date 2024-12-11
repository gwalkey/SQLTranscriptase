﻿<#
.SYNOPSIS
    Gets the SQL Server Logins on the target server, resolving Windows Groups to Users
	
.DESCRIPTION
   Writes the SQL Server Logins out to the "01 - Server Logins" folder
   One file for each login      
   
.EXAMPLE
    01_Server_Logins.ps1 localhost
	
.EXAMPLE
    01_Server_Logins.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

    # Requires the Powershell AD Module
	
	# Windows 10
	https://www.microsoft.com/en-us/download/details.aspx?id=45520
	
    # Windows 8.1
    http://www.microsoft.com/en-us/download/details.aspx?id=39296

    # Windows 8.0
    http://www.microsoft.com/en-us/download/details.aspx?id=28972

    # Windows 7
    http://www.microsoft.com/en-us/download/details.aspx?id=7887
	

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

try
{
    Import-Module ".\LoadSQLSmo.psm1"
}
catch
{
    Throw('LoadSQLSmo.psm1 not found')
}

LoadSQLSMO

# Load Powershell Module for AD Group Member Name Resolution
Import-Module ActiveDirectory

function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
            try
            {
			    if ($o.Schema -ne $null -and $o.Schema -ne "") 
                {
				    $schemaPrefix = $o.Schema + "."
			    }
            }
            catch 
            {
            }
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"
			$scripter.EnumScript($o)
		}
	}
}

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "01 - Server Logins"
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


# New UP SMO Object
if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $scripter 	= New-Object "Microsoft.SqlServer.Management.SMO.Scripter" $SQLInstance
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)    
    $scripter   = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

# Set scripter options to ensure only schema is scripted
$scripter.Options.ScriptSchema 	        = $true;
$scripter.Options.ScriptData 	        = $false;
$scripter.Options.ToFileOnly 			= $true;


# On-Domain Check
if ($env:computername -eq $env:userdomain) 
    {$OnDomain = $false}
else
    {$OnDomain = $true}

# If we are part of a Domain, Load the AD Module if it is installed on the user's system
if ($OnDomain -eq $true)
{
    $ADModuleExists = $false
    try
    {
        $old_ErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'    
        
    
        # Test if Im on a windows Domain, If so and we find Windows Group SQL Logins, resolve all related Windows AD Users
        $MyDCs = Get-ADDomainController -Filter * | Select-Object name
    
        if ($MyDCs -ne $null)
        {
            Write-Output "I am in a Domain - Resolving of AD Group-User Members Enabled"
            $ADModuleExists = $true
        }
        else
        {
            Write-Output "I am NOT in a Domain - Resolving of AD Group-User Members Disabled"
        }
    
        # Reset default PS error handler
        $ErrorActionPreference = $old_ErrorActionPreference 	
    
    }
    catch
    {
        # Reset default PS error handler
        $ErrorActionPreference = $old_ErrorActionPreference 
    
        # PS AD Module not installed
        Write-Output "AD Module Not Installed - AD Group User Resolution not attempted"
    }
}
else
{
    Write-Output "We are NOT in a Domain - Resolving of AD Group User Memberships Disabled"
}


# Create base output folder
$output_path = "$BaseFolder\$SQLInstance\01 - Server Logins\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# Create Windows Groups output folder
$WinGroupsPath = "$BaseFolder\$SQLInstance\01 - Server Logins\WindowsGroups\"
if(!(test-path -path $WinGroupsPath))
    {
        mkdir $WinGroupsPath | Out-Null
    }

# Create Windows Users output folder
$WinUsersPath = "$BaseFolder\$SQLInstance\01 - Server Logins\WindowsUsers\"
if(!(test-path -path $WinUsersPath))
    {
        mkdir $WinUsersPath | Out-Null
    }

# Create SQLAuth Users output folder
$SQLAuthUsersPath = "$BaseFolder\$SQLInstance\01 - Server Logins\SQLAuthUsers\"
if(!(test-path -path $SQLAuthUsersPath))
    {
        mkdir $SQLAuthUsersPath | Out-Null
    }


# Export Logins
$logins_path  = "$BaseFolder\$SQLInstance\01 - Server Logins\"
$logins = $srv.Logins

foreach ($Login in $Logins)
{

    # Skip non-Domain logins that look like Domain Logins (contain "\")
    if ($Login.Name -like "NT SERVICE\*") {continue}
    if ($Login.Name -like "NT AUTHORITY\*") {continue}    
    if ($Login.Name -like "IIS AppPool\*") {continue} 
    if ($Login.Name -eq "BUILTIN\Administrators") {continue}   
    if ($Login.Name -eq "##MS_PolicyEventProcessingLogin##") {continue}
    if ($Login.Name -eq "##MS_PolicyTsqlExecutionLogin##") {continue}
    if ($Login.Name -eq "##MS_SQLEnableSystemAssemblyLoadingUser##") {continue}
    if ($Login.Name -eq "##MS_SSISServerCleanupJobLogin##") {continue}

    Write-Output ("Scripting out: {0}" -f $Login.Name)

    # Process Windows Domain Groups
    if ($OnDomain -eq $true -and $ADModuleExists -eq $true -and $Login.LoginType -eq "WindowsGroup")
    {
            
        # Strip the Domain part off the SQL Login
        $ADName = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[1]
        $ADDomain = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[0]        

        $myFixedGroupName = $ADName.replace('\','_')
	    $myFixedGroupName = $myFixedGroupName.replace('/', '-')
	    $myFixedGroupName = $myFixedGroupName.replace('[','(')
	    $myFixedGroupName = $myFixedGroupName.replace(']',')')
	    $myFixedGroupName = $myFixedGroupName.replace('&', '-')
	    $myFixedGroupName = $myFixedGroupName.replace(':', '-')

        # Get the Domain I am in
        $MyDomain = Get-ADDomain -Current LocalComputer

        # ---------------------------
        # Resolve Users in AD Groups
        # ---------------------------
        if ($MyDomain.NetBIOSName -eq $ADDomain)
        {

            # One output folder per Windows Group        
            $WinGroupSinglePath = $WinGroupsPath+$myFixedGroupName+"\"
            if(!(test-path -path $WinGroupSinglePath))
            {
                mkdir $WinGroupSinglePath | Out-Null
            }
                
            # Get all Users of this AD Group
            try
            {
                #$ADGroupUsers = Get-ADGroupMember -Identity $ADName -Recursive -ErrorAction Stop | Where-Object {$_.objectClass -eq "user"} | Sort-Object name

                # Dec 11 2024 - switch to LDAP filter to overcome 5000 member AD limit 
                # First, Get the DistinguishedName of the Group
                $GroupDN = (Get-ADGroup -Identity $ADName).DistinguishedName
                $ADGroupUsers = Get-ADUser -LDAPFilter "(&(objectCategory=user)(memberof=$GroupDN))" -ErrorAction Stop | Sort-Object name
            }
            catch
            {
                Write-Output('Error Getting ADGroup Member [{0}]' -f $ADName)
                Write-Output('Error: [{0}]' -f $_.Exception.Message)
            }

            # Export Users for this AD Group
            $myoutputfile = $WinGroupSinglePath+"Users in "+$myFixedGroupName+".sql"
            $myoutputstring = "-- These Domain Users are members of the SQL Login and Windows Group ["+$ADName+ "]`n"
            $myoutputstring | Out-File -FilePath $myoutputfile -encoding ascii
       
            # Create the Group Itself
            CopyObjectsToFiles $login $WinGroupSinglePath

            # Script Out the individual Users in this Group
            foreach($ADUser in $ADGroupUsers)
            {   
                $Sam = $ADUser.SamAccountName            
    
                # Check Disabled Attribute
                $MyAdUser = Get-ADUser -LDAPFilter "(samaccountname=$Sam)"
                If ($MyAdUser.enabled -eq $false)
                {
                    # Create as Disabled if disabled in AD
                    $CreateObjectName = "CREATE LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] DISABLE;"
                }
                else
                {
                    $CreateObjectName = "CREATE LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] "
                }
                $CreateObjectName | Out-File -FilePath $myoutputfile -append -Encoding ascii
            }

        }
        else
        {
            # Since there is no way to enumerate Workgroup "groups"...sorry
            Write-Output ("Skipping local group {0}" -f $Login.Name)
        }
        
        
    }


    # Process Windows Users (Domain or Workgroup)
    if ($Login.LoginType -eq "WindowsUser")
    {            
        $fixedFileName2 = $Login.name.replace('\','_')

        # If the Ad Module is loaded and we are in a DOMAIN, do an AD Lookup to get the Account Enabled status, else SMO does the scripting below in the final else
        if ($OnDomain -eq $true -and $ADModuleExists -eq $true )
        {
         
            $MyDomain = Get-ADDomain -Current LocalComputer

            # Get Domain Part of Login Name if it exists
            if ($Login.Name -like "*\*")
            {                
                $ADDomain = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[0]
                $MyADUser = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[1]
            }
            else
            {
                $ADDomain = $null
                $MyADUser = $Login.Name
            }
            
            # We are in a Domain, and the domain portion of the Login Name MATCHES our Domain
            if ($ADDomain -ne $null -and $ADDomain -eq $MyDomain)
            {
                # Regular AD User - do the AD Lookup
                $MyADUser = $Login.Name

                $SAM = $Login.Name.Replace($ADDomain+"\",'')
                $MyAdUser = Get-ADUser -LDAPFilter "(SamAccountName=$SAM)"

                # Is an actual AD Account
                if ($MyAdUser.enabled -eq $false)
                {                    
                    $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$Login.Name+"] DISABLE;"
                }
                else            
                {
                    $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english];"
                }

            }
            #  We are in a domain, but the Domain portion of the Login Name does NOT match our Domain
            else
            {
                # Is Disabled?
                if ($Login.IsDisabled -eq $true)
                {
                   $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$Login.Name+"] DISABLE;"
                }
                else
                {
                   $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "
                }
            }            
        }

        else
        {
            # We are NOT in a Domain or the AD Module is not installed
            # Is Disabled?
            if ($Login.IsDisabled -eq $true)
            {
                $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$Login.Name+"] DISABLE;"
            }
            else
            {
                $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "
            }
        }
            
        # output results        
        $MyScriptingFilePath = $WinUsersPath+"\"+$fixedFileName2+".sql"
        $CreateObjectName | Out-File -FilePath $MyScriptingFilePath -Encoding ascii -Force
     }
     #else
     #{
     #   # Not on Domain or AD Module not loaded, get Windows User's object's property directly            
     #   $SQLCreateLogin = $Login.Script()
     #   $MyScriptingFilePath = $WinUsersPath+"\"+$fixedFileName2+".sql"
     #   $SQLCreateLogin | out-file -FilePath $MyScriptingFilePath -Encoding ascii -Force
     #}

    # -----------------------
    # Process SQL Auth Users
    # -----------------------
    if ($Login.LoginType -eq "SQLLogin")
    {
        CopyObjectsToFiles $login $SQLAuthUsersPath
    }

}
 

# MSDN Login Transfer Script (Passwords, SIDs)
# https://support.microsoft.com/en-us/kb/918992

# Create Hex SP First
$SQLCMD5 = 
"
USE [master]

IF (OBJECT_ID('sp_hexadecimal') IS NOT NULL)
  DROP PROCEDURE [sp_hexadecimal]

exec('
CREATE PROCEDURE [dbo].[sp_hexadecimal]
    @binvalue varbinary(256),
    @hexvalue varchar (514) OUTPUT
AS
DECLARE @charvalue varchar (514)
DECLARE @i int
DECLARE @length int
DECLARE @hexstring char(16)
SELECT @charvalue = ''0x''
SELECT @i = 1
SELECT @length = DATALENGTH (@binvalue)
SELECT @hexstring = ''0123456789ABCDEF''
WHILE (@i <= @length)
BEGIN
  DECLARE @tempint int
  DECLARE @firstint int
  DECLARE @secondint int
  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
  SELECT @firstint = FLOOR(@tempint/16)
  SELECT @secondint = @tempint - (@firstint*16)
  SELECT @charvalue = @charvalue +
    SUBSTRING(@hexstring, @firstint+1, 1) +
    SUBSTRING(@hexstring, @secondint+1, 1)
  SELECT @i = @i + 1
END

SET @hexvalue = @charvalue;
')



"

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $sqlresults5 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD5 -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL: {0}" -f $error[0])
        exit
    }
}
else
{
try
    {
        $sqlresults5 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD5 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL: {0}" -f $error[0])
        exit
    }
}



# Get Logins with Passwords and SIDs
$SQLCMD6 = 
"
set nocount on

DECLARE @OutputTable TABLE
(
	outstring nvarchar(max)
)

DECLARE @name sysname
DECLARE @type varchar (1)
DECLARE @hasaccess int
DECLARE @denylogin int
DECLARE @is_disabled int
DECLARE @PWD_varbinary  varbinary (256)
DECLARE @PWD_string  varchar (514)
DECLARE @SID_varbinary varbinary (85)
DECLARE @SID_string varchar (514)
DECLARE @tmpstr  varchar (1024)
DECLARE @is_policy_checked varchar (3)
DECLARE @is_expiration_checked varchar (3)
DECLARE @defaultdb sysname
 
DECLARE login_curs CURSOR FOR
SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name, l.hasaccess, l.denylogin 
FROM sys.server_principals p 
LEFT JOIN sys.syslogins l
ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa'
order by p.name

OPEN login_curs

FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin

WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN    
    IF (@type IN ( 'G', 'U'))
    BEGIN -- NT authenticated account/group
      SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
    END
    ELSE BEGIN -- SQL Server authentication
        -- obtain password and sid
        SET @PWD_varbinary = CAST( LOGINPROPERTY( @name, 'PasswordHash' ) AS varbinary (256) )
        EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT
        EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
 
        -- obtain password policy state
        SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
        SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
 
        SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'

        IF ( @is_policy_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
        END
        IF ( @is_expiration_checked IS NOT NULL )
        BEGIN
          SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
        END
    END
    IF (@denylogin = 1)
    BEGIN -- login is denied access
      SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME( @name )
    END
    ELSE IF (@hasaccess = 0)
    BEGIN -- login exists but does not have access
      SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO ' + QUOTENAME( @name )
    END
    IF (@is_disabled = 1)
    BEGIN -- login is disabled
      SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME( @name ) + ' DISABLE'
    END
	-- Add To output table
    insert into @OutputTable (outstring) values (@tmpstr)
  END

  FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
   END
CLOSE login_curs
deallocate login_curs

select * from @OutputTable

"

if ($serverauth -eq "win")
{
    try
    {
        $sqlresults6 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD6 -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL: {0}" -f $error[0])
        exit
    }
}
else
{
try
    {
        $sqlresults6 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD6 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL: {0}" -f $error[0])
        exit
    }
}

if ($sqlresults6 -ne $null)
{
    Write-Output ("SQL Logins with Passwords and SIDs: {0}" -f $sqlresults6.count)
    $myoutputfile4 = $output_path+"\Logins_with_Passwords_and_SIDs.sql"
    if (Test-Path $myoutputfile4) 
    {
        Remove-Item -path $myoutputfile4 -Force | out-null
    }
    
    Add-Content -Value "--- Logins for $sqlinstance `r`n" -Path $myoutputfile4 -Encoding Ascii

    foreach ($myLogin in $sqlresults6)
    {
        $myLogin.outstring | Out-File -FilePath $myoutputfile4 -Encoding ascii -append -width 1000
    }
}
else
{
    Write-Output "No Logins Found"
}


# Return To Base
set-location $BaseFolder