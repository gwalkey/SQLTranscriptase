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

    Once the Database Master Key is restored, the Syms and ASyms are restored (because they live in the databases)
    AKA, MS has no export routine for Sym/ASym keys

	Might have to run this Elevated (As Administrator) on Windows 8+

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs


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
Write-Host  -f Yellow -b Black "13 - PKI (Master keys, Asym Keys, Sym Keys, Certificates)"
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

# Get Major Version Only
[int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

switch ($ver)
{
    7  {Write-Output "SQL Server 7"}
    8  {Write-Output "SQL Server 2000"}
    9  {Write-Output "SQL Server 2005"}
    10 {Write-Output "SQL Server 2008/R2"}
    11 {Write-Output "SQL Server 2012"}
    12 {Write-Output "SQL Server 2014"}
    13 {Write-Output "SQL Server 2016"}
    14 {Write-Output "SQL Server 2017"}
	15 {Write-Output "SQL Server 2019"}
}


# New Up SMO Object
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

# if the Server's Backup Path is a UNC path, use it 
$unc = 0
if ($backupfolder -like "*\\*")
{
    $unc = 1
}


# Create Output Folder
$PKI_Path = "$BaseFolder\$SQLInstance\13 - PKI\"
if(!(test-path -path $PKI_path))
{
    mkdir $PKI_path | Out-Null	
}

Write-Output "Backup folder is $backupfolder"

# -------------------------------------
# 1) Service Master Key - Server Level
# -------------------------------------
Write-Output "`r`nSaving Service Master Key..."

$SQLCMD1 = "
backup service master key to file = N'$backupfolder\Service_Master_Key.txt'
encryption by password = 'SomeNewSecurePassword$!'
"

# Run SQL
if ($serverauth -eq "win")
{
    try
    {
        Connect-SQLServerExecuteNonQuery -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop
    }
    catch
    {
        Write-Output ("Error Doing Backup of Master Key: Error:[{0}]" -f $_.Exception.Message)
    }
}
else
{
    try
    {
        Connect-SQLServerExecuteNonQueryDMZ -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
       Write-Output ("Error Doing Backup of Master Key: Error:[{0}]" -f $_.Exception.Message)
    }
}


# Copy files down
set-location $BaseFolder

# Split out Windows Server name from the SQL instance
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
    
    try
    {
        copy-item $src "$PKI_Path" -ErrorAction stop
        remove-item $src -ErrorAction Stop
    }
    catch
    {
        Write-Output "Cant connect to $src"
    }
	

}

# ------------------------------------
# 2) Database Master Keys - DB Level
# ------------------------------------
set-location $BaseFolder
Write-Output "`r`nSaving Database Master Keys:"

foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in ('Model','MSDB','TempDB','SSISDB')) {continue}

    # Skip Offline Databases (SMO still enumerates them, but we cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }


    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')

    # Check for DB Master Key existence
    $sqlCMD2 = "
    Use $sqlDatabase;

    If (select Count(*) from sys.symmetric_keys where name like '%DatabaseMasterKey%') >0
    begin
	    select 1
    end
    else
    begin
	    select 0
    end
    "

    if ($serverauth -eq "win")
    {
        try
        {
	        $sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
        }
        catch
        {
            Write-Output("SQL Error getting symmetric key count, `r`nError:[{0}]" -f $_.Exception.Message)
        }
    }
    else
    {
        try
        {
            $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
        }
        catch
        {
            Write-Output("SQL Error getting symmetric key count, `r`nError:[{0}]" -f $_.Exception.Message)
        }

    }

    # Skip if no key found
    if ($sqlresults2.Column1 -eq 0) {continue}

    # Debug
    Write-Output "Exporting DataBase Master Key for Database: [$fixedDBName]"
    

    #Create output folder
    $output_path = $PKI_Path+$fixedDBName
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null	
    }
    
    # Export the DB Master Key
    $myExportedDBMasterKeyName = $backupfolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
    $sqlCMD3 = "
    use $fixedDBName;

    backup master key to file = N'$myExportedDBMasterKeyName'
	encryption by password = '3dH85Hhk003#GHkf02597gheij04'
    "

    # connect correctly
    $sqlresults3 = $null
    if ($serverauth -eq "win")
    {
        try
        {
	        $sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3
        }
        catch
        {
            Write-Output("SQL Error backing up master key on server, `r`nError:[{0}]" -f $_.Exception.Message)
        }
    }
    else
    {
        try
        {
            $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -User $myuser -Password $mypass
        }
        catch
        {
            Write-Output("SQL Error backing up master key on server, `r`nError:[{0}]" -f $_.Exception.Message)
        }
    }


    # No DB Master Key found, dont bother copying non-existent file
    if ($sqlresults3 -eq $null) {continue}
	
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
            copy-item $src $output_path -ErrorAction SilentlyContinue
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported DB Master key for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            Write-Output "Or run this script Elevated (as an administrator)"
            echo null > "$output_path\My DB Master key is in the SQL Backup Folder.txt"
        }
   	}
   	else
   	{
        # this script is running on the localhost, C:\ is OK
        if ($SQLInstance -eq "localhost")
        {
            $sourcefolder = $backupfolder
            $myExportedDBMasterKeyName = $sourcefolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
            $src = $myExportedDBMasterKeyName
        }
        else
        {
            # ON a remote server (D:\backups is \\server\d$\backups for me)
            $sourcefolder = $backupfolder.Replace(":","$")
            $myExportedDBMasterKeyName = $sourcefolder + "\" + $fixedDBName + "_Database_Master_Key.txt"
            $src = "\\"+$sqlinstance2+"\"+$myExportedDBMasterKeyName
        }
	   
        if(test-path -path $src)
        {
            copy-item $src $output_path -ErrorAction SilentlyContinue
            remove-item $src -ErrorAction SilentlyContinue
        }   
        else
        {
            Write-Output "Cant find exported DB Master key for $fixedDBName in $sourcefolder"
            Write-Output "Encrypted by Password instead of Service Master Key?"
            Write-Output "Or run this script Elevated (as an administrator)"
            echo null > "$output_path\My DB Master key is in the SQL Backup Folder.txt"
        }
   	}

}

 

# -------------------------------
# 3) Certificates from Master DB
# -------------------------------
Write-Output "`r`nSaving Certs:"

# Check for any Exisitng Certs
$sqlCMD4 = "
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
	$sqlresults4 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4
}
else
{
    $sqlresults4 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD4 -User $myuser -Password $mypass
}

# Export Certs if any found
if ($sqlresults4.Column1 -eq 1)
{

    $SQLCMD5 = "
    use master;

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
		    'USE master; '+char(13)+
		    'BACKUP CERTIFICATE [' + @CertName +'] '+
		    'TO FILE = '+char(39)+'$backupfolder\' + @OutputCer +char(39)+
		    ' WITH PRIVATE KEY '+
		    '(FILE = '+char(39)+'$backupfolder\'+@OutputPvk+char(39)+','+
		    ' ENCRYPTION BY PASSWORD = '+char(39)+'SomeNewSecurePassword$!'+char(39)+
		    ');'+char(13)
		
		    EXEC dbo.sp_executesql @SQLCommand
			--print @SQLCommand

		    FETCH NEXT FROM CertBackupCursor INTO @CertName
	    end

    CLOSE CertBackupCursor ;
    DEALLOCATE CertBackupCursor ;
    "


    if ($serverauth -eq "win")
    {
        Try
        {
            Connect-SQLServerExecuteNonQuery -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlcmd5 -ErrorAction Stop
        }
        catch
        {
            Write-Output ("Error Doing Certificate ScriptOut: Error:[{0}]" -f $_.Exception.Message)
        }
    }
    else
    {
        try
        {
            Connect-SQLServerExecuteNonQueryDMZ -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlcmd5 -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Write-Output ("Error Doing Certificate ScriptOut: Error:[{0}]" -f $_.Exception.Message)
        }
    }

    # copy-item fails if your location is SQLSERVER:
    set-location $BaseFolder

    # Put Master Certs in 'master' output folder
    $output_path = $PKI_Path+'master'
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
            try
            {
                $src = "$backupfolder\*.cer"
                copy-item $src $output_path -ErrorAction Stop
                remove-item $src -ErrorAction Stop

                $src = "$backupfolder\*.pvk"
                copy-item $src $output_path -ErrorAction Stop
                remove-item $src -ErrorAction Stop
            }
            catch
            {
                Write-Output ("Error copying Exported CER and PVK files to output folder: Error:[{0}]" -f $_.Exception.Message)
            }
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
            #gci $src
            Write-Output ("copy-item {0} to {1}" -f $src, $output_path)
            try
            {
                copy-item $src $output_path -ErrorAction Stop
                remove-item $src -ErrorAction Stop
            }
            catch
            {
                Write-Output ("Error copying Certificates to output folder: Error:[{0}]" -f $_.Exception.Message)
            }
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
            try
            {
                copy-item $src $output_path -ErrorAction Stop
                remove-item $src -ErrorAction Stop
            }
            catch
            {
                Write-Output ("Error copying Private Key files to output folder: Error:[{0}]" -f $_.Exception.Message)
            }
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

