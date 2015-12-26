<#
.SYNOPSIS
    Gets the Public Key Infrastructure Objects on the target server

.DESCRIPTION
   Writes the SQL PKI objects out to the "13 - PKI" folder   
   Using the SQL Server PKI Hierarchy, we write out:
   The Server-Level Service_Master_Key
   The Master Database's global Certificates and Private Keys
   Then each Database has its own Database_Master_Key, Certificates, Asymmetric and Symmetric Keys


.EXAMPLE
    13_PKI.ps1 localhost

.EXAMPLE
    13_PKI.ps1 server01 sa password

.NOTES
    This CANNOT Script Out Keys and Certs signed with passwords, unless you know the password and OPEN the Key/Cert first
    AKA, you will need to hard code that, or add a parameter to this script...
    Most Keys/Certs are signed with the Service Master Key, not the Database Master Key

    Once the Database Master Key is restored, the Syms and ASyms are restored (because they live in the database)
    AKA, MS has no export routine for Sym/ASym keys

	Might have to run this Elevated (As Administrator) on Windows 8+

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs


.LINK

#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "13 - PKI (Master keys, Asym Keys, Sym Keys, Certificates)"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./13_PKI.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ/SQL Auth machine)"
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


if ($serverauth -eq "win")
{
    $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLInstance
    $backupfolder = $srv.Settings.BackupDirectory
}
else
{
    $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLInstance 
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $backupfolder = $srv.Settings.BackupDirectory
}

# if a UNC path, use it 
$unc = 0
if ($backupfolder -like "*\\*")
{
    $unc = 1
}

# Dump PKI Objects 
# Write to default backup folder on host
$PKI_Path = "$BaseFolder\$SQLInstance\13 - PKI\"
if(!(test-path -path $PKI_path))
{
    mkdir $PKI_path | Out-Null	
}

Write-Output "Backup folder is $backupfolder"

# -------------------------------------
# 1) Service Master Key - Server Level
# -------------------------------------
Write-Output "Saving Service Master Key..."

$mySQLquery = "
backup service master key to file = N'$backupfolder\Service_Master_Key.txt'
encryption by password = 'SomeNewSecurePassword$!'
go
"
# connect correctly
if ($serverauth -eq "win")
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    $sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}

# Copy files down
# copy-item fails if your powershell "location" is SQLSERVER:
set-location $BaseFolder

#Get Windows Server name separate from the SQL instance
if ($SQLInstance.IndexOf('\') -gt 0)
{
    $SQLInstance2 = $SQLInstance.Substring(0,$sqlinstance.IndexOf('\'))
    Write-Output "Using $SQLInstance2"
}
else
{
    $SQLInstance2 = $SQLInstance
}

# Fix source folder for copy-item
if ($unc -eq 1)
{
    $sourcefolder = $backupfolder.Replace(":","$")
    $src = "$sourcefolder\Service_Master_Key.txt"
    if (!(test-path $src))
    {
        Write-Output "Cant connect to $src"
    }
    else
    {
        copy-item $src "$PKI_Path"
        # Leave no trace on server
        remove-item $src -ErrorAction SilentlyContinue 
    }
}
else
{    
    if ($SQLInstance -eq "localhost")
    {
        $sourcefolder = $backupfolder
        $src = "$sourcefolder\Service_Master_Key.txt"
    }
    else
    {
        $sourcefolder = $backupfolder.Replace(":","$")
        $src = "\\$sqlinstance2\$sourcefolder\Service_Master_Key.txt"
    }
    
	$old_ErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = 'SilentlyContinue'

    if (!(test-path $src))
    {
        Write-Output "Cant connect to $src"
    }
    else
    {
        copy-item $src "$PKI_Path"
        # Leave no trace on server
        remove-item $src -ErrorAction SilentlyContinue
    }
	
	# Reset default PS error handler - for WMI error trapping
	$ErrorActionPreference = $old_ErrorActionPreference 
}

# ------------------------------------
# 2) Database Master Keys - DB Level
# ------------------------------------
set-location $BaseFolder
Write-Output "Saving Database Master Keys:"

foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Model','MSDB','TempDB') {continue}

    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')

    # Check for DB Master Key existence
    $mySQLQuery = "
    Use $sqlDatabase;
    IF (select Count(*) from sys.symmetric_keys where name like '%DatabaseMasterKey%') >0
    begin
	    select 1
    end
    else
    begin
	    select 0
    end   
    "
    # connect correctly
	if ($serverauth -eq "win")
	{
		$sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
	}
	else
	{
		$sqlresults2 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
	}    

    # Skip if no key found
    if ($sqlresults2.Column1 -eq 0) {continue}

    # Tell User
    Write-Output "Exporting DB Master for $fixedDBName"
    

    #Create output folder
    $output_path = $PKI_Path+$fixedDBName
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null	
    }
    
    # Export the DB Master Key
    $myExportedDBMasterKeyName = $backupfolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
    $mySQLquery = "
    use $fixedDBName;
    backup master key to file = N'$myExportedDBMasterKeyName'
	encryption by password = '3dH85Hhk003#GHkf02597gheij04'
    "

    #Write-Output "SQL Backup Command is: "$mySQLquery

    # connect correctly
	if ($serverauth -eq "win")
	{
		$sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
	}
	else
	{
		$sqlresults = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
	}

	
    # copy-item fails if your location is SQLSERVER:
    set-location $BaseFolder

    # Fixup output folder if the backup folder is a UNC path
    if ($unc -eq 1)
    {
        $sourcefolder = $backupfolder.Replace(":","$")
        $myExportedDBMasterKeyName = $sourcefolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
   		$src = $myExportedDBMasterKeyName

        if(test-path -path $src)
        {
            copy-item $src $output_path
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported DB Master key for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            echo null > "$output_path\Cant find exported DB Master key.txt"
        }
   	}
   	else
   	{
        # this script is running on the localhost, C:\ is OK
        if ($SQLInstance -eq "localhost")
        {
            $sourcefolder = $backupfolder
            $myExportedDBMasterKeyName = $sourcefolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
            $src = "$myExportedDBMasterKeyName"
        }
        else
        {
            # ON a remote server (D:\backups is \\server\d$\backups for me)
            $sourcefolder = $backupfolder.Replace(":","$")
            $myExportedDBMasterKeyName = $sourcefolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
            $src = "\\$sqlinstance2\$myExportedDBMasterKeyName"
        }
	   
        if(test-path -path $src)
        {
            #Write-Output "src: "$src
            #Write-Output "output_path:"$output_path
            copy-item $src "$output_path"
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported DB Master key for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            echo null > "$output_path\Cant find exported DB Master key.txt"
        }
   	}

}

 

# -------------------------------
# 3) Certificates from Master DB
# -------------------------------
Write-Output "Saving Certs:"

# Check for Exisitng Certs
$mySQLQuery = "
    IF (SELECT count(*) FROM [master].[sys].[certificates] where name not like '##MS_%') >0
    begin
        select 1
    end
    else
    begin
        select 0    
    end
    "
# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults22 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
	$sqlresults22 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}    

# Export Certs if any found
if ($sqlresults22.Column1 -eq 1)
{
    $mySQLquery = "
    DECLARE @CertName  VARCHAR(128)
    DECLARE @OutputCer VARCHAR(128)
    DECLARE @OutputPvk VARCHAR(128)
    DECLARE @Sqlcommand nvarchar(max)
    DECLARE CertBackupCursor CURSOR READ_ONLY FORWARD_ONLY FOR
    SELECT name
      FROM [master].[sys].[certificates]
      where name not like '##MS_%'

    OPEN CertBackupCursor
    FETCH NEXT FROM CertBackupCursor INTO @CertName
    WHILE (@@FETCH_STATUS = 0)
	    begin
		    select @outputCer = @CertName+'.cer'
		    select @outputPvk = @CertName+'.pvk'

		    SET @SQLCommand = 
		    'USE master ;'+
		    'BACKUP CERTIFICATE ' + @CertName +' '+
		    'TO FILE = '+char(39)+'$backupfolder\' + @OutputCer +char(39)+
		    '	WITH PRIVATE KEY '+
		    '('+
		    ' FILE = '+char(39)+'$backupfolder\'+@OutputPvk+char(39)+','+
		    ' ENCRYPTION BY PASSWORD = '+char(39)+'SomeNewSecurePassword$!'+char(39)+
		    ');'
		
		    EXEC dbo.sp_executesql @SQLCommand

		    FETCH NEXT FROM CertBackupCursor INTO @CertName
	    end

    CLOSE CertBackupCursor ;
    DEALLOCATE CertBackupCursor ;
    "

    # connect correctly
    if ($serverauth -eq "win")
    {
        $sqlresults3 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue
    }
    else
    {
        $sqlresults3 = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
    }

    # copy-item fails if your location is SQLSERVER:
    set-location $BaseFolder

    # Put Master Certs in 'master' output folder
    $output_path = $PKI_Path+'\master'
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null	
    }

    # Fixup output folder if backup folder is UNC path
    if ($unc -eq 1)
    {
        $backupfolder = $backupfolder.Replace(":","$")
        # Test-Path
        if (!(test-path $backupfolder))
        {
            Write-Output "Cant connect to $backupfolder"
        }
        else
        {
            $src = "$backupfolder\*.cer"
            copy-item $src "$output_path" 
            remove-item $src -ErrorAction SilentlyContinue

            $src = "$backupfolder\*.pvk"
            copy-item $src "$output_path"
            remove-item $src -ErrorAction SilentlyContinue
        }
    }
    else
    {
        # Process *.CER files
        # If on localhost, C:\ is OK
        if ($SQLInstance -eq "localhost")
        {
            $sourcefolder = $backupfolder
            $myExportedCerts = $sourcefolder + "\*.cer"
            $src = $myExportedCerts
        }
        else
        {
            # From a remote server (D:\backups for a remote server is \\server\d$\backups for me)
            $sourcefolder = $backupfolder.Replace(":","$")
            $myExportedCerts = $sourcefolder + "\*.cer"
            $src = "\\$sqlinstance2\$myExportedCerts"
        }
	   
        if(test-path -path $src)
        {
            copy-item $src "$output_path"
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported Certificates for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            echo null > "$output_path\Cant find exported Certs.txt"
        }

        
        # Process *.PVK Files
        # localhost and this script on same box, C:\ is OK
        if ($SQLInstance -eq "localhost")
        {
            $sourcefolder = $backupfolder
            $myExportedCerts = $sourcefolder + "\*.pvk"
            $src = $myExportedCerts
        }
        else
        {
            # From remote server (D:\backups for a remote server is \\server\d$\backups for me)
            $sourcefolder = $backupfolder.Replace(":","$")
            $myExportedCerts = $sourcefolder + "\*.pvk"
            $src = "\\$sqlinstance2\$myExportedCerts"
        }
	   
        if(test-path -path $src)
        {
            copy-item $src "$output_path"
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported Certificates for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            echo null > "$output_path\Cant find exported Certs.txt"
        }
       
    }

# If any Certs Found
} 


set-location $BaseFolder

