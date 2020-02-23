<#
.SYNOPSIS
    Gets the Managed Backups on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "17 - Managed Backups" folder
   Saves the Master Switch settings to the file "Managed_Backups_Server_Settings.sql"
   And the Managed Backup settings for each Database into its own folder with the filename "Managed_Backup_Settings.sql"
   Managed Backups save your Databases automatically to an Azure Blob Storage Container using locally stored Credentials
   
.EXAMPLE
    17_Managed_Backups.ps1 localhost
	
.EXAMPLE
    17_Managed_Backups.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs


.NOTES
	https://msdn.microsoft.com/en-us/library/dn449497(v=sql.120).aspx

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

try
{
    Import-Module ".\LoadSQLSmo.psm1"
}
catch
{
    Throw('LoadSQLSmo.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "17 - Managed Backups"
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


# Bail if not 2014 or greater
if ($ver -lt 12)
{
    Write-Output "Not 2014 or greater...exiting"
    echo null > "$BaseFolder\$SQLInstance\17 - Managed Backups - Requires SQL 2014 or greater.txt"
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
$output_path = "$BaseFolder\$SQLInstance\17 - Managed Backups\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# Bail out if Managed Backups not setup yet, nothing to do
if ($srv.smartadmin.backupenabled -eq "false")
{
    Write-Output ("Managed Backups not setup yet, see https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-managed-backup-to-microsoft-azure?view=sql-server-2017:")
    set-location $BaseFolder
    exit
}

# Export Server-Level Settings
New-Item "$output_path\Managed_Backups_Server_Settings.sql" -type file -force  |Out-Null

# Managed Backups Master ON Switch
Add-Content -Value "--- Managed Backups Configuration for $SQLInstance `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
Add-Content -Value "--- Master Switch `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
if ($srv.SmartAdmin.MasterSwitch -eq "true")
{
    Add-Content -Value "EXEC [msdb].[smart_admin].[sp_backup_master_switch] @new_state  = 1; `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
}
else
{
    Add-Content -Value "EXEC [msdb].[smart_admin].[sp_backup_master_switch] @new_state  = 0; `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
}

# Instance-Level Default Settings
[string]$strEXEC = "EXEC [msdb].[smart_admin].[sp_set_instance_backup] "

Add-Content -Value "--- Default Instance-Level Settings for $SQLInstance `r`n" -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii
if ($srv.SmartAdmin.BackupEnabled -eq "true")
{
    $strEXEC += " `r`n @enable_backup = 1 `r`n"
}
else
{
    $strEXEC += " `r`n @enable_backup = 0 `r`n"
}


$strEXEC += " ,@retention_days = "        + $srv.smartadmin.BackupRetentionPeriodInDays+" `r`n"
$strEXEC += " ,@credential_name = N'"     + $srv.smartadmin.CredentialName+"' `r`n"
$strEXEC += " ,@storage_url= N'"          + $srv.smartadmin.StorageUrl+"' `r`n"
$strEXEC += " ,@encryption_algorithm= N'" + $srv.smartadmin.EncryptionAlgorithm+"' `r`n"
$strEXEC += " ,@encryptor_type= N'"       + $srv.smartadmin.EncryptorType+"' `r`n"
$strEXEC += " ,@encryptor_name= N'"       + $srv.smartadmin.EncryptorName+"'; `r`n"


# push out concatenated string
Add-Content $strEXEC -Path "$output_path\Managed_Backups_Server_Settings.sql" -Encoding Ascii

$sqlCMD2 = "USE msdb; SELECT `
distinct db_name, 
is_managed_backup_enabled, 
storage_url, 
retention_days, 
credential_name, 
encryption_algorithm, 
encryptor_type, 
encryptor_name
FROM
smart_admin.fn_backup_db_config(null) where is_managed_backup_enabled=1
order by 1
"


if ($serverauth -eq "win")
{
	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
}
else
{
    $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
}


# Script out
[int]$countproperty = 0;

foreach ($MB in $sqlresults2)
{    
    $db = $MB.db_name
    $fixedDBName = $db.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $DBOutput_path = "$BaseFolder\$SQLInstance\17 - Managed Backups\$fixedDBname"

    # Only create path if something to write
    if(!(test-path -path $DBOutput_path))
    {
        mkdir $DBOutput_path | Out-Null
    }

    $myoutputfile   = $DBOutput_path+"\Managed_Backup_Settings.sql"
    $myoutputstring = "--- Managed Backup for " + $fixedDBName + " `r`n"
    $myoutputstring += "Use msdb  `r`nGO `r`n`r`n EXEC smart_admin.sp_set_db_backup `r`n"
    $myoutputstring += " @database_name='"+ $MB.db_name+ "' `r`n"
    $myoutputstring += " ,@enable_backup=1 `r`n"
    $myoutputstring += " ,@storage_url= '" + $MB.storage_url + "' `r`n"
    $myoutputstring += " ,@retention_days= '" + $MB.retention_days + "' `r`n"
    $myoutputstring += " ,@credential_name= N'" + $MB.credential_name + "' `r`n"
    $myoutputstring += " ,@encryption_algorithm= N'" + $MB.encryption_algorithm + "' `r`n"
    $myoutputstring += " ,@encryptor_type= N'" + $MB.encryptor_type + "' `r`n"
    $myoutputstring += " ,@encryptor_name= N'" + $MB.encryptor_name + "' `r`n"

    $myoutputstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 500
	
	$fixedDBName

    $countproperty = $countproperty +1;
}

Write-Output ("{0} Managed Backup Jobs Exported" -f $countproperty)


# Return To Base
set-location $BaseFolder

