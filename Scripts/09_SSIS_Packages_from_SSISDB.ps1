<#
.SYNOPSIS
    Gets the SQL Server Integration Services Catalog objects on the target server
	
.DESCRIPTION
   Writes the SSIS Packages out to the "09 - SSISDB" folder
   
.EXAMPLE
    09_SSIS_Packages_from_SSISDB.ps1 localhost
	
.EXAMPLE
    09_SSIS_Packages_from_SSISDB.ps1 server01 sa password

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
Import-Module ".\SQLTranscriptase.psm1"
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "09 - SSIS Packages from SSISDB"
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



# Get Folder Structure 
$sqlCMD2 = 
"
SELECT 
    f.name as 'Folder',
    j.name as 'Project'
FROM 
    [SSISDB].[catalog].[projects] j
inner join 
    [SSISDB].[catalog].[folders] f
on 
    j.[folder_id] = f.[folder_id]
order by 
    1,2
"

# See if the SSISDB Catalog Exists first
$Folders = @()
if ($serverauth -eq "sql")
{
	Write-Output "Using SQL Auth"
	
	# See if the SSISDB Catalog Exists first
	[bool]$exists = $FALSE
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
    $server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
    $server.ConnectionContext.Password=$mypass
    $backupfolder = $server.Settings.BackupDirectory

	# if a UNC path, use it 
    $unc = 0
    if ($backupfolder -like "*\\*")
    {
        $unc = 1
    }

    # Only if the Catalog is found  
    if ($server.Databases["SSISDB"] ) { $exists = $true } else { $exists = $false }
	
	if ($exists -eq $FALSE)
    {
        Write-Output "SSISDB Catalog not found on $SQLInstance"
        # Create output folder
        $fullfolderPath = "$BaseFolder\$sqlinstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }	
        Write-Output "SSIS Catalog not found or version NOT 2012+"
        echo null > "$BaseFolder\$SQLInstance\09 - SSISDB Catalog - Not found.txt"
        Set-Location $BaseFolder
        exit
    }
 
    # Get folders
    try
    {
        $Folders = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }

}
else
{
	Write-Output "Using Windows Auth"
	
	# See if the SSISDB Catalog Exists first		
	$exists = $FALSE
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
	$backupfolder = $server.Settings.BackupDirectory

	# if the Backup Directory is a UNC path, use it 
    $unc = 0
    if ($backupfolder -like "*\\*")
    {
        $unc = 1
    }
   
    # Only if the Catalog is found    
    if ( $null -ne $server.Databases["SSISDB"] ) { $exists = $true } else { $exists = $false }

	if ($exists -eq $FALSE)
    {
        Write-Output "SSISDB Catalog not found on $SQLInstance"
        # Create output folder
        $fullfolderPath = "$BaseFolder\$sqlinstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }	
        Write-Output "SSIS Catalog not found or version NOT 2012+"
        echo null > "$BaseFolder\$SQLInstance\09 - SSISDB Catalog - Not found.txt"
        Set-Location $BaseFolder
        exit
    }
 

    # Get folders
    try
    {
        $Folders = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }

}

# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\09 - SSISDB"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}
	
# Script out Packages as ISPAC files
Write-Output "Writing out Packages in .ISPAC format..."
Foreach ($folder in $Folders)
{
    $foldername = $folder.folder
	$prjname = $folder.project

    Write-Output('Folder: [{0}]' -f $foldername)
    Write-Output('     Project: [{0}]' -f $prjname)

    # Create Output Folder for each SSIS Folder
    $SSISFolderPath = "$BaseFolder\$sqlinstance\09 - SSISDB\$foldername"
    if(!(test-path -path $SSISFolderPath))
    {
        mkdir $SSISFolderPath | Out-Null
    }
	
	# Create Outfolder for Each Project under the Folder
	$SSISProjectPath = $SSISFolderPath +"\$prjname"
	if(!(test-path -path $SSISProjectPath))
    {
        mkdir $SSISProjectPath | Out-Null
    }
	
    # Script out the ISPAC using BCP and a format file
    bcp "exec [ssisdb].[catalog].[get_project] '$foldername','$prjname'" queryout "$SSISProjectPath\$prjname.ispac" -S $SQLInstance -T -f "$BaseFolder\ssisdb.fmt" | Out-Null
    Write-Output('          Package: [{0}]' -f $prjname)

    # ----------------------
	# Create Deploy Script
    # ----------------------
	$SSISProjectPathDeploy = $SSISProjectPath+"\Redeploy_Script.sql"
	$DeploySQL = "
	DECLARE @ProjectBinary as varbinary(max)
	DECLARE @operation_id as bigint
	Set @ProjectBinary = (SELECT * FROM OPENROWSET(BULK '$SSISProjectPath\$prjname.ispac', SINGLE_BLOB) as BinaryData)
	Exec [SSISDB].[catalog].[deploy_project] @folder_name = '$foldername', @project_name = '$prjname', @Project_Stream = @ProjectBinary, @operation_id = @operation_id out;
    "
	
	$DeploySQL | out-file -FilePath $SSISProjectPathDeploy -encoding ascii -force

}

# --------------
# Environments
# --------------
# Get the Folder Structure

$fquery = "
use SSISDB;

select	
	f.[name] as 'Folder',
	e.[name] as 'Environment',
    e.description
from 
	catalog.environments e
join 
	catalog.folders f
on 
	f.folder_id = e.folder_id
order by
    1,2
"

# Get folder structure
if ($serverauth -eq "win")
{
    try
    {
        $fresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $fquery -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}
else
{
try
    {
        $fresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $fquery -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

# Enumerate Environments
foreach ($fe in $fresults)
{

    $foldername = $fe.folder
    $envname    = $fe.environment
    $envdesc    = $fe.description
    Write-Output ("Folder: [{0}]" -f $foldername)
    Write-Output ("     Environment: [{0}]" -f $envname)
    Write-Output ("     Description: [{0}]" -f $envdesc)

    # Create Environments Subfolder for this SSIS Folder
    $SSISEnvFolderPath = "$BaseFolder\$sqlinstance\09 - SSISDB\$foldername\Environments\"
    if(!(test-path -path $SSISenvFolderPath))
    {
        mkdir $SSISEnvFolderPath | Out-Null
    }

    # Construct Create Statement 
    $CreateEnvstring = "
    exec ssisdb.catalog.create_environment
        @folder_name = N'$foldername',
        @environment_name = N'$envname',
        @environment_description = N'$envdesc';
    "

    # Write Out
    $myoutputfile = $SSISEnvFolderPath+$envname+"_env.sql"
    $CreateEnvstring | out-file -FilePath $myoutputfile -append -encoding ascii -width 50000        

    # Script out Environment Variables   
    $envVresults = @()
    $envVquery = 
    "
    USE SSISDB;

    select
    'declare @var '+
    case
        when v.type = 'Boolean' then 'bit'
        when v.type = 'Byte' then 'tinyint'
        when v.type = 'Datetime' then 'Datetime'
        when v.type = 'Decimal' then 'decimal(38,18)'
        when v.type = 'Double' then 'float'
        when v.type = 'Int16' then 'smallint'
        when v.type = 'Int32' then 'int'
        when v.type = 'Int64' then 'bigint'
        when v.type = 'SByte' then 'smallint'
        when v.type = 'Single' then 'float'
        when v.type = 'String' then 'sql_variant'
        when v.type = 'UInt32' then 'bigint'
        when v.type = 'IInt4' then 'bigint'
    end +
    '= N'+ char(39)+cast(v.value as nvarchar(max))+char(39)+'; '+
    'exec ssisdb.catalog.create_environment_variable '+
    '@Folder_name = '+char(39)+f.name+char(39)+', '+
    '@environment_name = '+char(39)+e.name+char(39)+ ', '+
    '@variable_name = '+char(39)+ v.name+char(39)+ ', '+
    '@description = ' +char(39)+v.[Description]+char(39)+ ', '+
    '@sensitive = '+char(39)+ case when v.sensitive=0 then '0' else '1' end +char(39)+ ', '+
    '@data_type = N'+char(39)+v.Type+char(39)+ ', '+
    '@value = @var`r`nGO'
    from
    	catalog.environments e
    inner join
    	catalog.folders f
    on 
    	e.folder_id = f.folder_id
    inner join
    	catalog.environment_variables v
    on
    	e.environment_id = v.environment_id
    where
        f.name = '"+$foldername +"'
    order by
    	f.name, e.name, v.name
    "
    
    
    # Get Vars
    if ($serverauth -eq "win")
    {
        try
        {
            $envVresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $envVquery -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }
    else
    {
    try
        {
            $envVresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $envVquery -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }

    # Write Out
    foreach ($envV in $envVresults)
    {
        $myoutputVfile = $SSISEnvFolderPath+$envname+"_variables.sql"
        $envV.column1 | out-file -FilePath $myoutputVfile -append -encoding ascii -width 50000        
    }
    
    # Get Next Folder
}

# Status
if ($Folders -ne $null -and @($Folders).count -gt 0)
{
    Write-Output ("{0} Packages Exported" -f @($Folders).count)
}

# Return To Base
set-location $BaseFolder
