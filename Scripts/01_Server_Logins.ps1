<#
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

    # Install the Powershell AD Module
	
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


Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)


Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

#  Script Name
Write-Host  -f Yellow -b Black "01 - Server Logins"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Logins.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

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
		$SqlAdapter.Fill($DataSet) |out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

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
		$SqlAdapter.Fill($DataSet) |out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

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

# Set Local Vars
$server = $SQLInstance


# Create SMO Object to Server
if ($serverauth -eq "win")
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object "Microsoft.SqlServer.Management.SMO.Scripter" $server
}
else
{
    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)    
    $scripter   = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

# Set scripter options to ensure only schema is scripted
$scripter.Options.ScriptSchema 	        = $true;
$scripter.Options.ScriptData 	        = $false;
$scripter.Options.ToFileOnly 			= $true;


# The SMO ActiveDirectory Object holds Domain/Workgroup membership status of the Target Server
$OnDomain = $false
if ($srv.ActiveDirectory -ne $null)
{
    $OnDomain = $true
    Write-Output ("Server On Domain? Yes")
}
else
{
    Write-Output ("Server On Domain? No")
}


# If we are part of a Domain, Load the AD Module if it is installed on the user's system
if ($OnDomain -eq $true)
{
    $ADModuleExists = $false
    try
    {
        $old_ErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
    
        Import-Module ActiveDirectory
    
        # Test if Im on a windows Domain, If so and we find Windows Group SQL Logins, resolve all related Windows AD Users
        $MyDCs = Get-ADDomainController -Filter * | Select-Object name
    
        if ($MyDCs -ne $null)
        {
            Write-Output "Domain Controller found - Resolving of AD Group User Memberships Enabled"
            $ADModuleExists = $true
        }
        else
        {
            Write-Output "Domain Controller NOT found - Resolving of AD Group User Memberships Disabled - are you in a Workgroup?"
        }
    
        # Reset default PS error handler
        $ErrorActionPreference = $old_ErrorActionPreference 	
    
    }
    catch
    {
        # Reset default PS error handler
        $ErrorActionPreference = $old_ErrorActionPreference 
    
        # PS AD Module not installed
        Write-Output "AD Module Not Found - AD Group User Resolution not attempted"
    }
}
else
{
    Write-Output "Target Server is NOT in a Domain - Resolving of AD Group User Memberships Disabled"
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

    #Write-Output ("Name: {0}, Creation Date:{1}, Last Mod: {2}" -f $login.name, $login.CreateDate, $Login.DateLastModified)

    # Skip non-Domain logins that look like Domain Logins (contain "\")
    if ($Login.Name -like "NT SERVICE\*") {continue}
    if ($Login.Name -like "NT AUTHORITY\*") {continue}    
    if ($Login.Name -like "IIS AppPool\*") {continue} 
    if ($Login.Name -eq "BUILTIN\Administrators") {continue}   
    if ($Login.Name -eq "##MS_PolicyEventProcessingLogin##") {continue}
    if ($Login.Name -eq "##MS_PolicyTsqlExecutionLogin##") {continue}
    if ($Login.Name -eq "##MS_SQLEnableSystemAssemblyLoadingUser##") {continue}
    if ($Login.Name -eq "##MS_SSISServerCleanupJobLogin##") {continue}

    # Process Windows Domain Groups
    if ($OnDomain -eq $true -and $ADModuleExists -eq $true -and $Login.LoginType -eq "WindowsGroup")
    {

        # For this SQL Login, resolve all Windows Users in this AD Group and below in the AD Tree - recursive        

        # Strip the Domain part off the SQL Login
        $ADName = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[1]
        $ADDomain = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[0]

        $myFixedGroupName = $ADName.replace('\','_')
	    $myFixedGroupName = $myFixedGroupName.replace('/', '-')
	    $myFixedGroupName = $myFixedGroupName.replace('[','(')
	    $myFixedGroupName = $myFixedGroupName.replace(']',')')
	    $myFixedGroupName = $myFixedGroupName.replace('&', '-')
	    $myFixedGroupName = $myFixedGroupName.replace(':', '-')

        # Is this a LOCAL Windows Group (on the server itself) or on the same DOMAIN I am on?
        # Get My Domain
        $MyDomain = Get-ADDomain -Current LocalComputer

        # Process Windows Groups in the current domain (me and the server are in the same domain/workgroup)
        if ($MyDomain.NetBIOSName -eq $ADDomain)
        {
        
            Write-Output ("Scripting out: {0}" -f $Login.Name)

            # One output folder per Windows Group        
            $WinGroupSinglePath = $WinGroupsPath+$myFixedGroupName+"\"
            if(!(test-path -path $WinGroupSinglePath))
            {
                mkdir $WinGroupSinglePath | Out-Null
            }
                
            # Get all Users of this AD Group
            $ADGroupUsers = Get-AdGroupMember -identity $ADName -recursive | sort name

            # Export Users for this AD Group
            $myoutputfile = $WinGroupSinglePath+"Users in "+$myFixedGroupName+".sql"
            $myoutputstring = "-- These Domain Users are members of the SQL Login and Windows Group ["+$ADName+ "]`n"
            $myoutputstring | out-file -FilePath $myoutputfile -encoding ascii
       
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
                    #Write-Output $Sam
                    $CreateObjectName = "CREATE LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] DISABLE;"
                }
                else
                {
                    $CreateObjectName = "CREATE LOGIN ["+$ADDomain+"\"+$ADUser.SamAccountName+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] "
                }
                $CreateObjectName | out-file -FilePath $myoutputfile -append -Encoding ascii
            }

        }
        else
        {
            # Treat these local (to the machine) groups as users
            Write-Output ("Skipping local group {0}" -f $Login.Name)
        }
        
        
    }


    # Process Windows Users (Domain or Workgroup)
    if ($Login.LoginType -eq "WindowsUser")
    {
        Write-Output ("Scripting out: {0}" -f $Login.Name)
        #CopyObjectsToFiles $login $WinUsersPath

        $fixedFileName2 = $Login.name.replace('\','_')
        # If the Ad Module is loaded and the Target Server is on a DOMAIN, do an AD Lookup to get the Account Enabled status, else SMO does the scripting
        if ($OnDomain -eq $true -and $ADModuleExists -eq $true )
        {
         
            # Get Target Server Domain if not same as ours, example DMZ Servers
            $ADDomain = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[0]
            

            # Remote Domain <> Our Domain means we are talking to a Workgroup Server using Local Accounts
            if ($ADDomain -eq $SQLInstance)
            {
                $MyAdUser = ($Login.Name -split {$_ -eq "," -or $_ -eq "\"})[1]
            }
            else
            {
                # Regular Domain Account on same Domain as us
                $SAM = $Login.Name.Replace($ADDomain+"\",'')
                $MyAdUser = Get-ADUser -LDAPFilter "(SamAccountName=$SAM)"
                # If AD lookup returns a NULL object for the SAM, Assume the Account is a LOCAL WINDOWS Account, not an AD Account
                if ($myAdUser -eq $null)
                {
                    # Is a Local Windows Account
                    if ($Login.IsDisabled -eq $true)
                    {
                        $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "+ "`r ALTER LOGIN ["+$Login.Name+"] DISABLE;"
                    }
                    else
                    {
                        $CreateObjectName = "CREATE LOGIN ["+$Login.Name+"] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]; "
                    }
                }
                else
                {
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
            }

            # output
            $MyScriptingFilePath = $WinUsersPath+"\"+$fixedFileName2+".sql"
            $CreateObjectName | out-file -FilePath $MyScriptingFilePath -Encoding ascii -Force
        }
        else
        {
            # Not on Domain or AD Module not loaded, get Windows User's object's property directly            
            $SQLCreateLogin = $Login.Script()
            $MyScriptingFilePath = $WinUsersPath+"\"+$fixedFileName2+".sql"
            $SQLCreateLogin | out-file -FilePath $MyScriptingFilePath -Encoding ascii -Force
        }
    }

    # Process SQL Auth Users
    if ($Login.LoginType -eq "SQLLogin")
    {
        Write-Output ("Scripting out: {0}" -f $Login.Name)
        CopyObjectsToFiles $login $SQLAuthUsersPath
    }

}
 
# Return To Base
set-location $BaseFolder

