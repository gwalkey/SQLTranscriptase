<#
.SYNOPSIS
    Recreate SSRS Objects from JSON files using SOAP or REST API
	
.DESCRIPTION   
    Objects Supported:

    Users
    FolderTree
    RDL Report Files
    Data Sources
    DataSets
    Subscriptions
    Shared Schedules
    Folder and Report Permissions
   
.EXAMPLE
    Recreate_SSRS_Objects.ps1 localhost
	
.EXAMPLE
    Recreate_SSRS_Objects.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

    Input files are expected to be in this folder/file structure:
    ------------------------------------------------------------
    Config
    EncryptionKey
    FolderTree
    Permissions
    Reports
    Schedules
    Subscriptions 
    Users

.Outputs

	
.NOTES

	
.LINK	
	
#>

[CmdletBinding()]
Param(
    [Parameter(Position=0,mandatory=$false)]
    [string]$SQLInstance='c0reportserver',
    [Parameter(Position=1,mandatory=$false)]
    [string]$InputObjectsPath="C:\dbscripts\reportsdb\11 - SSRS"
)

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Output("Server: [{0}]" -f $SQLInstance)

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ".\SQLTranscriptase.psm1"
}
catch
{
    Throw('SQLTranscriptase.psm1 Powershell Module Not Found')
    exit
}

try
{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch
{
    Throw('Active Directory Powershell Module Not Found')
    exit
}

# Database Server connection check
$SQLCMD1 = "select serverproperty('productversion') as 'Version'"
try
{
	$myver = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop | select -ExpandProperty Version
}
catch
{
    Write-Host -f red "$SQLInstance appears offline."
    Set-Location $BaseFolder
	exit
}

Write-Output('SSRS SQL Version: [{0}]' -f $myver)

# Get Version from HTML Page
function Get-SSRSVersion
{
    [CmdletBinding()]
    Param(
        [string]$SQLInstance
    )

    # Get SSRS (NOT SQL Server) Version
    try
    {
        $ssrsProxy = Invoke-WebRequest -Uri "http://$SQLInstance/reportserver" -UseDefaultCredential
    }
    catch
    {
        Write-Output('Error getting SSRS version from WebService: {0}' -f $_.Exception.Message)
        throw('Error getting SSRS version from WebService: {0}' -f $_.Exception.Message)
    }
    $content = $ssrsProxy.Content
    $Regex = [Regex]::new("(?<=Microsoft SQL Server Reporting Services Version )(.*)(?=`">)") 
    $match = $regex.Match($content)
    if($Match.Success)            
    {
        $Global:SSRSFamily = 'SSRS'
        $version = $Match.Value
    }
    else
    {
        # Try PowerBI Reporting Server
        $Regex = [Regex]::new("(?<=Microsoft Power BI Report Server Version )(.*)(?=`">)") 
        $match = $regex.Match($content)
        if($Match.Success)            
        {
            $Global:SSRSFamily = 'PowerBI'
            $version = $Match.Value
        }
        else
        {
            $Global:SSRSFamily = 'SSRS'
            $version = '0.0'
        }
    }

    $NumericVersion = $version.Split('.')
    
    Write-Output($NumericVersion[0]+'.'+$NumericVersion[1])
}

# REST API Endpoint
$URI = "http://$SQLInstance/reports/api/v2.0"

# Folder Paths for Import
$fullfolderPath = $InputObjectsPath
$fullfolderPathConfig = "$fullfolderPath\Config"
$fullfolderPathRDL = "$fullfolderPath\Reports"
$fullfolderPathSUB = "$fullfolderPath\Subscriptions"
$fullfolderPathKey = "$fullfolderPath\EncryptionKey"
$fullfolderPathFolders = "$fullfolderPath\FolderTree"
$fullfolderPathUsers = "$fullfolderPath\Users"
$fullfolderPathPermissions = "$fullfolderPath\Permissions"
$fullfolderPathDataSources = "$fullfolderPath\DataSources"
$fullfolderPathSchedules = "$fullfolderPath\Schedules"

if((test-path -path "$InputObjectsPath\SharedDatSourceImportErrors.txt"))
{
    remove-item "$InputObjectsPath\SharedDatSourceImportErrors.txt" | Out-Null
}

if((test-path -path "$InputObjectsPath\ReportImportErrors.txt"))
{
    remove-item "$InputObjectsPath\ReportImportErrors.txt" | Out-Null
}


# Get SSRS Version
try
{
    $SSRSVersion = Get-SSRSVersion $SQLInstance
}
catch
{
    Write-Output('{0}' -f $_.Exception.Message)
    exit
}

Write-Output ("SSRS Version: {0}" -f $SSRSVersion)
if ($SSRSVersion -ne '0.0')
{

    # 2005
    if ($SSRSVersion -eq '9.0')
    {
        "Supports SOAP Interface 2005"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2005.asmx"
        $RESTAPIURL=$null
    }

    # 2008
    if ($SSRSVersion -eq '10.0')
    {
        "Supports SOAP Interface 2005"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2005.asmx"
        $RESTAPIURL=$null
    }

    # 2008 R2
    if ($SSRSVersion -eq '10.5')
    {
        "Supports SOAP Interface 2010"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL=$null
    }

    # 2012
    if ($SSRSVersion -eq '11.0')
    {
        "Supports SOAP Interface 2010"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL=$null
    }

    # 2014
    if ($SSRSVersion -eq '12.0')
    {
        "Supports SOAP Interface 2010"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL=$null
    }

    # 2016
    if ($SSRSVersion -eq '13.0')
    {
        "Supports SOAP Interface 2010"
        "Supports REST Interface v1.0"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL="http://$SQLInstance/reports/api/v1.0"
    }

    # 2017
    if ($SSRSVersion -eq '14.0')
    {
        "Supports SOAP Interface 2010"
        "Supports REST Interface v2.0"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL="http://$SQLInstance/reports/api/v2.0"
    }
    
    # PowerBI
    if ($SSRSVersion -eq '15.0')
    {
        "Supports SOAP Interface 2010"
        "Supports REST Interface v2.0"
        $SOAPAPIURL="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIURL="http://$SQLInstance/reports/api/v2.0"
    }
}



# -----------
# 1) Users 
# SSRS Users no longer in AD are NOT ADDED to the Destination SSRS server
# -----------
Write-Output('Re-Creating Users...')
try
{
    $Users = Get-Content -Path "$fullfolderPathUsers\Users.json" | ConvertFrom-Json
}
catch
{
    Throw('Failed to load Users File [{0}]' -f "$fullfolderPathUsers\Users.json")
    exit
}
# Build List of Actrive Users to validate permisssions of departed AD Users below
$ActiveUsers = New-Object System.Collections.ArrayList

foreach($User in $Users)
{
    $UserName = $User.UserName
    $UserType = $User.UserType
    $AuthType = $User.AuthType
    #Write-Output('Processing User [{0}]' -f $UserName)

    # Is User still in Active Directory and Enabled?
    $DomainUser = $UserName.Split('\\')
    if (@($DomainUser).Count -gt 1) 
    {
        $UserNameOnly = $DomainUser[1]
    }
    else
    {
        $UserNameOnly = $DomainUser
    }

    # User?
    try
    {
        $ADUser = Get-ADUser -Identity $UserNameOnly -ErrorAction Stop        
    }
    catch
    {
        # Group
        try
        {
            $ADGroup = Get-ADGroup -Identity $UserNameOnly -ErrorAction Stop
        }
        catch
        {
            continue # Dont add to Users Table
        }
    }

    # Add Active AD User to validation Array
    $ActiveUsers.Add($user) |out-null

    # Add User to SSRS
    $sqlCMD1=
    "
    insert into users
    select newid(), suser_sid('$UserName'), $UserType, $AuthType, '$UserName',NULL,NULL,SYSDATETIME()
    "
    try
    {
        $SQLStatus = Connect-SQLServerExecuteNonQuery -SQLInstance $SQLInstance -Database 'ReportServer' -SQLExec $SQLCMD1 -ErrorAction Stop
    }
    catch
    {
        #Write-Output('Error: {0}' -f $_.Exception.Message)
    }

}



# -----------------------------------------
# 2) Folder Tree with Permissions/Policies 
# -----------------------------------------
Write-Output('Re-Creating Folder Tree Structure...')
$FolderTreeFile = $fullfolderPathFolders+'\FolderTreeStructure.json'
try
{
    $NewFolderTree = get-content -Path $FolderTreeFile | ConvertFrom-Json 
}
catch
{
    Throw('Failed to load FolderTreeFile [{0}]' -f $FolderTreeFile)
    exit
}

# Set Root Folder's permissions first, so we can inherit them below
$Rootfolder = $NewFolderTree | where-object {$_.path -eq '/'}

# Connect to SOAP Webservice
$rs = New-WebServiceProxy -Uri $SOAPAPIURL -UseDefaultCredential;
$type = $rs.GetType().Namespace
$PolicyDataType = ($type + '.Policy')
$ParmValueDataType = ($type + '.ParameterValue')
$RoleDataType = ($type + '.Role')
$PropertyDatatype = ($type + '.Property')

# Init Arrays for this folder
$folderPolicyArray = New-Object System.Collections.ArrayList

# Build up the Policies by User
$UniqueUsers = $Rootfolder.Policies | sort UserName -Unique | select Username
foreach ($UniqueUser in $UniqueUsers)
{
    # Skip restoring permissions for departed/inactive users
    if (!($ActiveUsers | where-object {$_.Username -in $UniqueUser.UserName}) -and $UniqueUser.UserName -notin ('BUILTIN\Administrators','NT AUTHORITY\Authenticated Users')) {continue}

    $pol = New-Object ($PolicyDataType)
    $pol.GroupUserName = $UniqueUser.UserName

    # Build overly complex Roles Object
    $roleArray = New-Object System.Collections.ArrayList
    $rolesforthisUser = ($Rootfolder.Policies |where-object {$_.UserName -eq $UniqueUser.UserName}).Rolename
    foreach($roleName in $rolesforthisUser)
    {
        # Skip this Role until Microsoft explains this
        if ($roleName -eq 'Subscription Manager'){continue}

        $role = New-Object ($RoleDataType)
        $Role.Name = $roleName
        $role.Description=''
        $roleArray.add($role) | Out-Null
    }   
    
    $pol.Roles = $roleArray
    $folderPolicyArray.add($pol) | out-null
}    

# Apply the policy
try
{
    $PolicyID = $rs.SetPolicies('/',$folderPolicyArray)
}
catch
{
    Write-Output('Error Setting Policies on Folder [{0}]' -f $error[0])
}

# Create remaining Folder Structure (folders, inheritance, permissions)
# NOTE: All Folders are created with INHERIT = YES using either SOAP or REST
# So then, we must set new policies on all Folders having PolicyRoot=1
$nonRootFolders = $NewFolderTree | where-object {$_.path -ne '/'}
foreach($folder in $nonRootFolders)
{   
    Write-Output('Processing Folder [{0}]'-f $folder.path)
    $folderPath = $folder.Path
    $FolderPolicyRoot = $folder.PolicyRoot
    $FolderPolicies= $folder.Policies

    # Get Folder name from Path
    $LastBackslash = $folderPath.LastIndexOf('/')
    $folderName = $folderPath.Substring($LastBackslash+1)
    

    # Get Folder Parent from Path
    $split = $folderpath.Split('/')
    if($split.Count -eq 2)
    {
        $folderParent='/'
    }
    else
    {
        $tmpParent = $split[1..($split.count-2)]
        $tmpCombine = $tmpParent -join '/'
        $folderParent ='/'+$tmpCombine
    }


    # Create Folder using SOAP
    $prop = New-Object ($PropertyDataType)
    $prop.Name = 'Hidden'
    $prop.Value = $false
    $FolderProperties = New-Object System.Collections.ArrayList
    $FolderProperties.Add($prop) | Out-Null
    
    # Create
    try
    {
        $FolderID = $rs.CreateFolder($folderName,$FolderParent,$FolderProperties)
    }
    catch
    {
        Write-Output('Error Creating Folder [{0}]' -f $error[0])
    }

    
    # Init Policy Array for WebService call
    $folderPolicyArray = New-Object System.Collections.ArrayList

    # Build up the Policies by User
    $UniqueUsers = $FolderPolicies | sort UserName -Unique | select Username
    foreach ($UniqueUser in $UniqueUsers)
    {

        # Skip restoring permissions for departed/inactive users
        if (!($ActiveUsers | where-object {$_.Username -in $UniqueUser.UserName}) -and $UniqueUser.UserName -notin ('BUILTIN\Administrators','NT AUTHORITY\Authenticated Users')) {continue}

        $pol = New-Object ($PolicyDataType)
        $pol.GroupUserName = $UniqueUser.UserName

        # Build overly complex Roles Object
        $roleArray = New-Object System.Collections.ArrayList
        $rolesforthisUser = ($FolderPolicies | where-object {$_.UserName -eq $UniqueUser.UserName}).Rolename
        foreach($roleName in $rolesforthisUser)
        {
            # Skip this Role until Microsoft explains this missing from SSRS 2017
            if ($roleName -eq 'Subscription Manager'){continue}

            $role = New-Object ($RoleDataType)
            $Role.Name = $roleName
            $role.Description=''
            $roleArray.add($role) | out-null
        }
    
        $pol.Roles = $roleArray
        $folderPolicyArray.add($pol) | Out-null
    }

    
    # If Inherit = false, apply the policy 
    if ($FolderPolicyRoot -eq $true)
    {
        try
        {
            $PolicyID = $rs.SetPolicies($folderPath,$folderPolicyArray)
        }
        catch
        {
            Write-Output('Error Setting Policies on Folder [{0}]' -f $error[0])
        }
    }
    
    
}


# -----------------------
# 3) Shared Schedules
# Subscriptions can use a shared schedule instead of an embedded schedule
# ----------------------
Write-Output('Restoring Shared Schedules...')
try
{
    $SharedSchedules = Get-Content -Path "$fullfolderPathSchedules\SharedSchedules.json" | ConvertFrom-Json
}
catch
{
    Throw('Failed to load ReportPaths File [{0}]' -f "$fullfolderPathSchedules\SharedSchedules.json")
    exit
}

# Get UserID we can use as a placeholder for the Shared Schedules CreadtedBy attribute
$sqlCMDGetSA=
"
SELECT UserID FROM Users WHERE [UserName]='BUILTIN\Administrators'
"

# New up needed objects
$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;"
$DataSet = New-Object System.Data.DataSet
$Connection = New-Object System.Data.SqlClient.SqlConnection
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$Connection.ConnectionString = $SQLConnectionString
$SqlCmd.CommandText = $sqlCMDGetSA
$SqlCmd.Connection = $Connection
$SqlCmd.CommandTimeout=0
$SqlAdapter.SelectCommand = $SqlCmd

    
# Insert results into Dataset table
$SqlAdapter.Fill($DataSet) |out-null
if ($DataSet.Tables.Count -ne 0) 
{
    $SAResults = $DataSet.Tables[0]
}
else
{
    $SAResults =$null
}

# Close connection to sql server
$Connection.Close()

# Insert Each Schedule Item
if($SAResults -ne $null)
{
    $SAUserID= $SAResults.UserId.Guid

    # Reset CreatedByID to SA because we dont care who created the Shared Schedule, and not all departed users were carried over to the new server
    foreach ($SS in $SharedSchedules)
    {

        $sqlCMDSkedInsert=
        "
        INSERT INTO dbo.Schedule
        (
            ScheduleID,
            Name,
            StartDate,
            Flags,
            NextRunTime,
            LastRunTime,
            EndDate,
            RecurrenceType,
            MinutesInterval,
            DaysInterval,
            WeeksInterval,
            DaysOfWeek,
            DaysOfMonth,
            Month,
            MonthlyWeek,
            State,
            LastRunStatus,
            ScheduledRunTimeout,
            CreatedById,
            EventType,
            EventData,
            Type,
            ConsistancyCheck,
            Path
        )
        VALUES
        (   
            newid(),
            @Name,
            @StartDate,
            @Flags,
            @NextRunTime,
            @LastRunTime,
            @EndDate,
            @RecurrenceType,
            @MinutesInterval,
            @DaysInterval,
            @WeeksInterval,
            @DaysOfWeek,
            @DaysOfMonth,
            @Month,
            @MonthlyWeek,
            @State,
            @LastRunStatus,
            @ScheduledRunTimeout,
            @CreatedById,
            @EventType,
            @EventData,
            @Type,
            @ConsistancyCheck,
            @Path
            )
        "

        $SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;" 
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
        $Connection.Open()

		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $sqlCMDSkedInsert
		$SqlCmd.Connection = $Connection
        $SqlCmd.CommandTimeout=0

        # Type the Parameters
        $sqlCmd.Parameters.Add("@Name",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
        $sqlCmd.Parameters.Add("@StartDate",[System.Data.SqlDBType]::DateTime)| Out-Null
        $sqlCmd.Parameters.Add("@Flags",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@NextRunTime",[System.Data.SqlDBType]::DateTime)| Out-Null
        $sqlCmd.Parameters.Add("@LastRunTime",[System.Data.SqlDBType]::DateTime)| Out-Null
        $sqlCmd.Parameters.Add("@EndDate",[System.Data.SqlDBType]::DateTime)| Out-Null
        $sqlCmd.Parameters.Add("@RecurrenceType",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@MinutesInterval",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@DaysInterval",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@WeeksInterval",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@DaysOfWeek",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@DaysOfMonth",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@Month",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@MonthlyWeek",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@State",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@LastRunStatus",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
        $sqlCmd.Parameters.Add("@ScheduledRunTimeout",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@CreatedById",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
        $sqlCmd.Parameters.Add("@EventType",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
        $sqlCmd.Parameters.Add("@EventData",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
        $sqlCmd.Parameters.Add("@Type",[System.Data.SqlDBType]::Int,4)| Out-Null
        $sqlCmd.Parameters.Add("@ConsistancyCheck",[System.Data.SqlDBType]::DateTime)| Out-Null
        $sqlCmd.Parameters.Add("@Path",[System.Data.SqlDBType]::NVarChar,260)| Out-Null

        # Add Values with DBNull handling
        if ($SS.Name -eq $null)
        {
            $sqlcmd.Parameters["@Name"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@Name"].Value = $SS.Name
        }

        if ($SS.StartDate -eq $null)
        {
            $sqlcmd.Parameters["@StartDate"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@StartDate"].Value = $SS.StartDate
        }

        if ($SS.Flags -eq $null)
        {
            $sqlcmd.Parameters["@Flags"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@Flags"].Value = $SS.Flags
        }
        
        if ($SS.NextRunTime -eq $null)
        {
            $sqlcmd.Parameters["@NextRunTime"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@NextRunTime"].Value = $SS.NextRunTime
        }
        
        if ($SS.LastRunTime -eq $null)
        {
            $sqlcmd.Parameters["@LastRunTime"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@LastRunTime"].Value = $SS.LastRunTime
        }

        if ($SS.EndDate -eq $null)
        {
            $sqlcmd.Parameters["@EndDate"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@EndDate"].Value = $SS.EndDate
        }

        if ($SS.RecurrenceType -eq $null)
        {
            $sqlcmd.Parameters["@RecurrenceType"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@RecurrenceType"].Value = $SS.RecurrenceType
        }

        
        if ($SS.MinutesInterval -eq $null)
        {
            $sqlcmd.Parameters["@MinutesInterval"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@MinutesInterval"].Value = $SS.MinutesInterval
        }

        
        if ($SS.DaysInterval -eq $null)
        {
            $sqlcmd.Parameters["@DaysInterval"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@DaysInterval"].Value = $SS.DaysInterval
        }

        
        if ($SS.WeeksInterval -eq $null)
        {
            $sqlcmd.Parameters["@WeeksInterval"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@WeeksInterval"].Value = $SS.WeeksInterval
        }

        if ($SS.DaysOfWeek -eq $null)
        {
            $sqlcmd.Parameters["@DaysOfWeek"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@DaysOfWeek"].Value = $SS.DaysOfWeek
        }

        if ($SS.DaysOfMonth -eq $null)
        {
            $sqlcmd.Parameters["@DaysOfMonth"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@DaysOfMonth"].Value = $SS.DaysOfMonth
        }

        if ($SS.Month -eq $null)
        {
            $sqlcmd.Parameters["@Month"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@Month"].Value = $SS.Month
        }

        if ($SS.MonthlyWeek -eq $null)
        {
            $sqlcmd.Parameters["@MonthlyWeek"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@MonthlyWeek"].Value = $SS.MonthlyWeek
        }

        if ($SS.State -eq $null)
        {
            $sqlcmd.Parameters["@State"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@State"].Value = $SS.State
        }

        if ($SS.LastRunStatus -eq $null)
        {
            $sqlcmd.Parameters["@LastRunStatus"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@LastRunStatus"].Value = $SS.LastRunStatus
        }

        if ($SS.ScheduledRunTimeout -eq $null)
        {
            $sqlcmd.Parameters["@ScheduledRunTimeout"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@ScheduledRunTimeout"].Value = $SS.ScheduledRunTimeout
        }
         
        if ($SS.CreatedById -eq $null)
        {
            $sqlcmd.Parameters["@CreatedById"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@CreatedById"].Value = [guid]$SAUserID
        }

        if ($SS.EventType -eq $null)
        {
            $sqlcmd.Parameters["@EventType"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@EventType"].Value = $SS.EventType
        }

        if ($SS.EventData -eq $null)
        {
            $sqlcmd.Parameters["@EventData"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@EventData"].Value = $SS.EventData
        }

        if ($SS.Type -eq $null)
        {
            $sqlcmd.Parameters["@Type"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@Type"].Value = $SS.Type
        }

        if ($SS.ConsistancyCheck -eq $null)
        {
            $sqlcmd.Parameters["@ConsistancyCheck"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@ConsistancyCheck"].Value = $SS.ConsistancyCheck
        }

        if ($SS.Path -eq $null)
        {
            $sqlcmd.Parameters["@Path"].Value = [System.DBNull]::Value
        }
        else
        {
            $sqlcmd.Parameters["@Path"].Value = $SS.Path
        }


        try
        {
            $SqlCmd.ExecuteNonQuery() | Out-Null
            $Connection.Close()
        }
        catch
        {
            Write-Output('Error INSERTING SQL Shared Schedules')
            Write-Output('Error: {0}' -f $ERROR[0])
        }

    }

}


# ------------------------------------------------------------------------------------------------
# 4) Catalog Items
# RDL Reports with Embedded Data Sources
# Shared Data Sources
# Shared DataSets
# These are all Catalog Items (Datasources and Data Sets publish into hard-wired top-level folders by SSDT)
# ------------------------------------------------------------------------------------------------
try
{
    $ReportPaths = Get-Content -Path "$fullfolderPathRDL\ReportPathDataSource.json" | ConvertFrom-Json
}
catch
{
    Throw('Failed to load ReportPaths File [{0}]' -f "$fullfolderPathUsers\ReportPathDataSource.json")
    exit
}

# Separate Catalog Item Types
$sharedDataSources = $ReportPaths | where-object {$_.Type -eq 5}
$sharedDataSets = $ReportPaths | where-object {$_.Type -eq 8}
$RDLReports = $ReportPaths | where-object {$_.Type -eq 2}

# Type 5 - Shared Data Sources
# Import Shared Data Sources (Catalog Type 5 Items) first 
# because regular RDL (Catalog Type 2 Items) and Shared DataSets (Catalog Type 8) may be depedent on these.
Write-Output('Restoring Shared DataSources...')
foreach($RDL in $sharedDataSources)
{
    # Connect to SOAP Service
    $reportPath = $RDL.path
    $reportName = $RDL.Name
    $reportVis  = $RDL.Hidden
    Write-Output('{0}' -f $reportPath)
    
    $rs = New-WebServiceProxy -Uri $SOAPAPIURL -UseDefaultCredential;
    $type = $rs.GetType().Namespace
    $Propertydatatype = ($type + '.Property')

    # Method Call Properties
    $DescProp = New-Object($Propertydatatype)
    $DescProp.Name = 'Description'
    $DescProp.Value = ''
    $HiddenProp = New-Object($Propertydatatype)
    $HiddenProp.Name = 'Hidden'
    $HiddenProp.Value = 'false'

    $Properties = @($DescProp, $HiddenProp)
    
    # Fixup the Path to the RDL file
    $FileName = $RDL.Path.replace('/','\')+'.rdl'
    $RDLFileName = $fullfolderPathRDL+$FileName
    if (([regex]::Matches($reportPath, "/" )).count -eq 1)
    {
        $SSRSDestinationFolder='/'
    }
    else
    {
        $SSRSDestinationFolder = $reportPath.Replace('/'+$reportname,'')
    }

    # Get RDL as byte array
    $bytes = [io.file]::ReadAllBytes($RDLFileName)

    $warnings = $null

    # Upload the dataSource
    try
    {
        $objReport = $rs.CreateCatalogItem('DataSource',$reportName, $SSRSDestinationFolder, $true, $bytes, $Properties, [ref]$warnings)
        $NewItemID = $objReport.ID
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        Write-output('Error Restoring [{0}]' -f $reportName)
        $reportName | out-file -FilePath "$InputObjectsPath\SharedDataSourceImportErrors.txt" -Append -Encoding ascii
        Write-Output("{0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SharedDataSourceImportErrors.txt" -Append -Encoding ascii
        continue
    }

    # Fixup the Restored DataSource using the new ItemID    
    foreach($DS in $RDL.DataSources)
    {
        $DSItemID = $DS.ItemID
        $DSSubscriptionID = $DS.SubscriptionID
        $DSName = $DS.Name
        $DSExtension = $DS.Extension
        $DSLink = $DS.Link
        $DSCredRet = $DS.CredentialRetrieval
        $DSPrompt = $DS.Prompt
        $DSConnectionString = $DS.ConnectionString
        $DSOrigConnString = $DS.OriginalConnectionString
        $DSOrigConnStringExpr = $DS.OriginalConnectStringExpressionBased
        $DSUserName = $DS.UserName
        $DSPassword = $DS.Password
        $DSFlags = $DS.Flags
        $DSVersion = $DS.Version

        $sqlCMDDS=
        "UPDATE 
            ReportServer.dbo.DataSource
         Set
            SubscriptionID=@DSSubScriptionID,
            Name=@DSName,
            Extension=@DSExtension,
            Link=@DSLink,
            CredentialRetrieval=@DSCredRet,
            Prompt=@DSPrompt,
            ConnectionString=@DSConnectionString,
            OriginalConnectionString=@DSOrigConnString,
            OriginalConnectStringExpressionBased=@DSOrigConnStringExpr,
            UserName=@DSUserName,
            Password=@DSPassword,
            Flags=@DSFlags,
            Version=@DSVersion
         Where
            ItemID = '$NewItemID'
        "

        try
        {
		    $SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;" 
		    $Connection = New-Object System.Data.SqlClient.SqlConnection
		    $Connection.ConnectionString = $SQLConnectionString
            $Connection.Open()

		    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		    $SqlCmd.CommandText = $sqlCMDDS
		    $SqlCmd.Connection = $Connection
            $SqlCmd.CommandTimeout=0

            # Type the Parameters
            $sqlCmd.Parameters.Add("@DSSubscriptionID",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSName",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSExtension",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSLink",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSCredRet",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSPrompt",[System.Data.SqlDBType]::NText)| Out-Null
            $sqlCmd.Parameters.Add("@DSConnectionString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnStringExpr",[System.Data.SqlDBType]::Bit)| Out-Null
            $sqlCmd.Parameters.Add("@DSUserName",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSPassword",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSFlags",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSVersion",[System.Data.SqlDBType]::Int,4)| Out-Null

            # Add Values with DBNull handling
            if ($DS.SubscriptionID -eq $null)
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [guid]($DS.SubscriptionID)
            }

            if ($DS.Name -eq $null)
            {
                $sqlcmd.Parameters["@DSName"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSName"].Value = $DS.Name
            }

            if ($DS.Extension -eq $null)
            {
                $sqlcmd.Parameters["@DSExtension"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSExtension"].Value = $DS.Extension
            }

            if ($DS.Link -eq $null)
            {
                $sqlcmd.Parameters["@DSLink"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSLink"].Value = [guid]$NewItemID
            }

            if ($DS.CredentialRetrieval -eq $null)
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=$DS.CredentialRetrieval
            }

            if ($DS.Prompt -eq $null)
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=$DS.Prompt
            }

            if ($DS.ConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[byte[]]$DS.ConnectionString
            }

            if ($DS.OriginalConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[byte[]]$DS.OriginalConnectionString
            }

            if ($DS.OriginalConnectStringExpressionBased -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=$DS.OriginalConnectStringExpressionBased
            }

            if ($DS.UserName -eq $null)
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[byte[]]$DS.UserName
            }

            if ($DS.Password -eq $null)
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[byte[]]$DS.Password
            }

            if ($DS.Flags -eq $null)
            {
                $sqlcmd.Parameters["@DSFlags"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSFlags"].Value=$DS.Flags
            }

            if ($DS.Version -eq $null)
            {
                $sqlcmd.Parameters["@DSVersion"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSVersion"].Value=$DS.Version
            }

            $SqlCmd.ExecuteNonQuery() | Out-Null
            $Connection.Close()        
        }
        catch
        {
            Write-Output('Error: {0}' -f $_.Exception.Message)
            Write-Output("Error: {0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SharedDataSourceImportErrors.txt" -Append -Encoding ascii
            Write-Output($DS)
        }
    }
    
    # Restore Object Permissions
}


# Type 8 - Shared Data Sets
Write-Output('Restoring Shared Data Sets...')
foreach($RDL in $sharedDataSets)
{
    # Connect to SOAP Service
    $reportPath = $RDL.path
    $reportName = $RDL.Name
    $reportVis  = $RDL.Hidden
    Write-Output('{0}' -f $reportPath)
    
    $rs = New-WebServiceProxy -Uri $SOAPAPIURL -UseDefaultCredential;
    $type = $rs.GetType().Namespace
    $Propertydatatype = ($type + '.Property')

    # Method Call Properties
    $DescProp = New-Object($Propertydatatype)
    $DescProp.Name = 'Description'
    $DescProp.Value = ''
    $HiddenProp = New-Object($Propertydatatype)
    $HiddenProp.Name = 'Hidden'
    $HiddenProp.Value = $reportVis

    $Properties = @($DescProp, $HiddenProp)
    
    # Fixup the Path to the RDL file
    $FileName = $RDL.Path.replace('/','\')+'.rdl'
    $RDLFileName = $fullfolderPathRDL+$FileName
    if (([regex]::Matches($reportPath, "/" )).count -eq 1)
    {
        $SSRSDestinationFolder='/'
    }
    else
    {
        $SSRSDestinationFolder = $reportPath.Replace('/'+$reportname,'')
    }

    # Get RDL as byte array
    $bytes = [io.file]::ReadAllBytes($RDLFileName)

    # break out Shared Data Source from DatSet XML Content
    $enc = [System.Text.Encoding]::ASCII
    $shDSetContent = $enc.Getstring($bytes)
    $Regex = [Regex]::new("(<DataSourceReference>)(.*)(</DataSourceReference>)") 
    $match = $regex.Match($shDSetContent)
    if($Match.Success)            
    {
        $SharedDataSourceName = $Match.Value.Replace('<DataSourceReference>','').Replace('</DataSourceReference>','')
    }
    else
    {
        $SharedDataSourceName = $null
    }


    $warnings = $null

    # Upload the dataSource
    try
    {
        $objReport = $rs.CreateCatalogItem('DataSet',$reportName, $SSRSDestinationFolder, $true, $bytes, $Properties, [ref]$warnings)
        $NewItemID = $objReport.ID
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        Write-output('Error Restoring [{0}]' -f $reportName)
        $reportName | out-file -FilePath "$InputObjectsPath\SharedDataSetImportErrors.txt" -Append -Encoding ascii
        Write-Output("{0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SharedDataSetImportErrors.txt" -Append -Encoding ascii
        continue
    }

    # Fixup the Restored DataSource using the new ItemID    
    foreach($DS in $RDL.DataSources)
    {
        $DSItemID = $DS.ItemID
        $DSSubscriptionID = $DS.SubscriptionID
        $DSName = $DS.Name
        $DSExtension = $DS.Extension
        $DSLink = $DS.Link
        $DSCredRet = $DS.CredentialRetrieval
        $DSPrompt = $DS.Prompt
        $DSConnectionString = $DS.ConnectionString
        $DSOrigConnString = $DS.OriginalConnectionString
        $DSOrigConnStringExpr = $DS.OriginalConnectStringExpressionBased
        $DSUserName = $DS.UserName
        $DSPassword = $DS.Password
        $DSFlags = $DS.Flags
        $DSVersion = $DS.Version

        # if DSLink <> null, we are using a Shared Data Source, get it's guid by Name
        if ($DS.Link -ne $null)
        {
            #Write-Output('Linking Report to Shared DataSource')
            $sqlCMD4=
            "
            SELECT
	            ItemID
            FROM
                catalog
            WHERE 
                [name]='$SharedDataSourceName'
	            AND [type]=5
            "
            try
            {
                $SharedDSLinkage = ConnectWinAuth -SQLInstance $SQLInstance -Database 'ReportServer' -SQLExec $sqlCMD4 -ErrorAction Stop
                $DSLink = $SharedDSLinkage.ItemId.Guid
            }
            catch
            {
                Write-Output('Error getting shared Dataset ItemID')
                Write-Output("{0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SharedDataSetImportErrors.txt" -Append -Encoding ascii
                $DSLink=$DS.Link
            }
        }

        $sqlCMDDS=
        "UPDATE 
            ReportServer.dbo.DataSource
         Set
            SubscriptionID=@DSSubScriptionID,
            Name=@DSName,
            Extension=@DSExtension,
            Link=@DSLink,
            CredentialRetrieval=@DSCredRet,
            Prompt=@DSPrompt,
            ConnectionString=@DSConnectionString,
            OriginalConnectionString=@DSOrigConnString,
            OriginalConnectStringExpressionBased=@DSOrigConnStringExpr,
            UserName=@DSUserName,
            Password=@DSPassword,
            Flags=@DSFlags,
            Version=@DSVersion
         Where
            ItemID = '$NewItemID'
        "

        try
        {
		    $SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;" 
		    $Connection = New-Object System.Data.SqlClient.SqlConnection
		    $Connection.ConnectionString = $SQLConnectionString
            $Connection.Open()

		    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		    $SqlCmd.CommandText = $sqlCMDDS
		    $SqlCmd.Connection = $Connection
            $SqlCmd.CommandTimeout=0

            # Type the Parameters
            $sqlCmd.Parameters.Add("@DSSubscriptionID",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSName",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSExtension",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSLink",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSCredRet",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSPrompt",[System.Data.SqlDBType]::NText)| Out-Null
            $sqlCmd.Parameters.Add("@DSConnectionString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnStringExpr",[System.Data.SqlDBType]::Bit)| Out-Null
            $sqlCmd.Parameters.Add("@DSUserName",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSPassword",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSFlags",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSVersion",[System.Data.SqlDBType]::Int,4)| Out-Null

            # Add Values with DBNull handling
            if ($DS.SubscriptionID -eq $null)
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [guid]($DS.SubscriptionID)
            }

            if ($DS.Name -eq $null)
            {
                $sqlcmd.Parameters["@DSName"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSName"].Value = $DS.Name
            }

            if ($DS.Extension -eq $null)
            {
                $sqlcmd.Parameters["@DSExtension"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSExtension"].Value = $DS.Extension
            }

            if ($DS.Link -eq $null)
            {
                $sqlcmd.Parameters["@DSLink"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSLink"].Value = [guid]$DSLink
            }

            if ($DS.CredentialRetrieval -eq $null)
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=$DS.CredentialRetrieval
            }

            if ($DS.Prompt -eq $null)
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=$DS.Prompt
            }

            if ($DS.ConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[byte[]]$DS.ConnectionString
            }

            if ($DS.OriginalConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[byte[]]$DS.OriginalConnectionString
            }

            if ($DS.OriginalConnectStringExpressionBased -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=$DS.OriginalConnectStringExpressionBased
            }

            if ($DS.UserName -eq $null)
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[byte[]]$DS.UserName
            }

            if ($DS.Password -eq $null)
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[byte[]]$DS.Password
            }

            if ($DS.Flags -eq $null)
            {
                $sqlcmd.Parameters["@DSFlags"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSFlags"].Value=$DS.Flags
            }

            if ($DS.Version -eq $null)
            {
                $sqlcmd.Parameters["@DSVersion"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSVersion"].Value=$DS.Version
            }

            $SqlCmd.ExecuteNonQuery() | Out-Null
            $Connection.Close()        
        }
        catch
        {
            Write-Output('Error: {0}' -f $_.Exception.Message)
            Write-Output("Error: {0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SharedDataSetImportErrors.txt" -Append -Encoding ascii
            Write-Output($DS)
        }        
    }
    
}



# Type 2
# Import regular RDL (Catalog Item Type 2) Reports
Write-Output('Restoring Reports...')
foreach($RDL in $RDLReports)
{
    # Connect to SOAP Service
    $reportPath = $RDL.path
    $reportName = $RDL.Name
    $reportVis  = $RDL.Hidden
    $reportPolicies = $RDL.Policies
    $reportPolicyRoot = $RDL.PolicyRoot

    Write-Output('{0}' -f $reportPath)
    
    $rs = New-WebServiceProxy -Uri $SOAPAPIURL -UseDefaultCredential;
    $type = $rs.GetType().Namespace
    $Propertydatatype = ($type + '.Property')

    # Method Call Properties
    $DescProp = New-Object($Propertydatatype)
    $DescProp.Name = 'Description'
    $DescProp.Value = ''
    $HiddenProp = New-Object($Propertydatatype)
    $HiddenProp.Name = 'Hidden'   
    $HiddenProp.Value = $reportVis

    $Properties = @($DescProp, $HiddenProp)
    
    # Fixup the Path to the RDL file
    $FileName = $RDL.Path.replace('/','\')+'.rdl'
    $RDLFileName = $fullfolderPathRDL+$FileName
    if (([regex]::Matches($reportPath, "/" )).count -eq 1)
    {
        $SSRSDestinationFolder='/'
    }
    else
    {
        $SSRSDestinationFolder = $reportPath.Replace('/'+$reportname,'')
    }

    # Get RDL as byte array
    $bytes = [io.file]::ReadAllBytes($RDLFileName)

    $warnings = $null

    # Upload the Report
    try
    {
        $objReport = $rs.CreateCatalogItem('Report',$reportName, $SSRSDestinationFolder, $true, $bytes, $Properties, [ref]$warnings)
        $NewItemID = $objReport.ID
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        Write-output('Error Restoring [{0}]' -f $reportName)
        $reportName | out-file -FilePath "$InputObjectsPath\ReportImportErrors.txt" -Append -Encoding ascii
        Write-Output("{0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\ReportImportErrors.txt" -Append -Encoding ascii
        continue
    }

    # Fixup the Restored DataSource using the new ItemID    
    foreach($DS in $RDL.DataSources)
    {
        $DSItemID = $DS.ItemID
        $DSSubscriptionID = $DS.SubscriptionID
        $DSName = $DS.Name
        $DSExtension = $DS.Extension
        $DSLink = $DS.Link # - Used to Link to Shared DataSource (Type 5 Catalog Item)
        $DSCredRet = $DS.CredentialRetrieval
        $DSPrompt = $DS.Prompt
        $DSConnectionString = $DS.ConnectionString
        $DSOrigConnString = $DS.OriginalConnectionString
        $DSOrigConnStringExpr = $DS.OriginalConnectStringExpressionBased
        $DSUserName = $DS.UserName
        $DSPassword = $DS.Password
        $DSFlags = $DS.Flags
        $DSVersion = $DS.Version

        # if DSLink <> null, we are using a Shared Data Source, get it's guid by Name
        if ($DS.Link -ne $null)
        {
            #Write-Output('Linking Report to Shared DataSource')
            $sqlCMD2=
            "
            SELECT
	            x.ItemId,
	            c.[path] AS 'Report',
	            s.[name] AS 'DataSource'
            FROM
	            catalog x
            JOIN
	            dbo.DataSource s
            ON 
	            x.[name] = s.[name]
            JOIN
	            catalog c
            ON 
	            s.ItemId = c.Itemid
            WHERE 
	            c.[path]='$reportPath'
	            AND x.[type]=5
            "
            try
            {
                $SharedDSLinkage = ConnectWinAuth -SQLInstance $SQLInstance -Database 'ReportServer' -SQLExec $sqlCMD2 -ErrorAction Stop
                $DSLink = $SharedDSLinkage.ItemId.Guid
            }
            catch
            {
                Write-Output('Error getting Shared data Source ItemID')
                Write-Output("{0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\ReportImportErrors.txt" -Append -Encoding ascii
                $DSLink=$DS.Link
            }
        }

        $sqlCMDDS=
        "UPDATE 
            ReportServer.dbo.DataSource
         Set
            SubscriptionID=@DSSubScriptionID,
            Name=@DSName,
            Extension=@DSExtension,
            Link=@DSLink,
            CredentialRetrieval=@DSCredRet,
            Prompt=@DSPrompt,
            ConnectionString=@DSConnectionString,
            OriginalConnectionString=@DSOrigConnString,
            OriginalConnectStringExpressionBased=@DSOrigConnStringExpr,
            UserName=@DSUserName,
            Password=@DSPassword,
            Flags=@DSFlags,
            Version=@DSVersion
         Where
            ItemID = '$NewItemID' and [Name] = '$DSName'
        "

        try
        {
		    $SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;" 
		    $Connection = New-Object System.Data.SqlClient.SqlConnection
		    $Connection.ConnectionString = $SQLConnectionString
            $Connection.Open()

		    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		    $SqlCmd.CommandText = $sqlCMDDS
		    $SqlCmd.Connection = $Connection
            $SqlCmd.CommandTimeout=0

            # Type the Parameters
            $sqlCmd.Parameters.Add("@DSSubscriptionID",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSName",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSExtension",[System.Data.SqlDBType]::NVarChar,260)| Out-Null
            $sqlCmd.Parameters.Add("@DSLink",[System.Data.SqlDBType]::UniqueIdentifier)| Out-Null
            $sqlCmd.Parameters.Add("@DSCredRet",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSPrompt",[System.Data.SqlDBType]::NText)| Out-Null
            $sqlCmd.Parameters.Add("@DSConnectionString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnString",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSOrigConnStringExpr",[System.Data.SqlDBType]::Bit)| Out-Null
            $sqlCmd.Parameters.Add("@DSUserName",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSPassword",[System.Data.SqlDBType]::Image)| Out-Null
            $sqlCmd.Parameters.Add("@DSFlags",[System.Data.SqlDBType]::Int,4)| Out-Null
            $sqlCmd.Parameters.Add("@DSVersion",[System.Data.SqlDBType]::Int,4)| Out-Null

            # Add Values with DBNull handling
            if ($DS.SubscriptionID -eq $null)
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSSubscriptionID"].Value = [guid]($DS.SubscriptionID)
            }

            if ($DS.Name -eq $null)
            {
                $sqlcmd.Parameters["@DSName"].Value = [System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSName"].Value = $DS.Name
            }

            if ($DS.Extension -eq $null)
            {
                $sqlcmd.Parameters["@DSExtension"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSExtension"].Value = $DS.Extension
            }

            if ($DS.Link -eq $null)
            {
                $sqlcmd.Parameters["@DSLink"].Value =[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSLink"].Value = [guid]$DSLink
            }

            if ($DS.CredentialRetrieval -eq $null)
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSCredRet"].Value=$DS.CredentialRetrieval
            }

            if ($DS.Prompt -eq $null)
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPrompt"].Value=$DS.Prompt
            }

            if ($DS.ConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSConnectionString"].Value=[byte[]]$DS.ConnectionString
            }

            if ($DS.OriginalConnectionString -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnString"].Value=[byte[]]$DS.OriginalConnectionString
            }

            if ($DS.OriginalConnectStringExpressionBased -eq $null)
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSOrigConnStringExpr"].Value=$DS.OriginalConnectStringExpressionBased
            }

            if ($DS.UserName -eq $null)
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSUserName"].Value=[byte[]]$DS.UserName
            }

            if ($DS.Password -eq $null)
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSPassword"].Value=[byte[]]$DS.Password
            }

            if ($DS.Flags -eq $null)
            {
                $sqlcmd.Parameters["@DSFlags"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSFlags"].Value=$DS.Flags
            }

            if ($DS.Version -eq $null)
            {
                $sqlcmd.Parameters["@DSVersion"].Value=[System.DBNull]::Value
            }
            else
            {
                $sqlcmd.Parameters["@DSVersion"].Value=$DS.Version
            }

            $SqlCmd.ExecuteNonQuery() | Out-Null
            $Connection.Close()        
        }
        catch
        {
            Write-Output('Error: {0}' -f $_.Exception.Message)
            $reportName | out-file -FilePath "$InputObjectsPath\ReportImportErrors.txt" -Append -Encoding ascii
            Write-Output("Error: {0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\ReportImportErrors.txt" -Append -Encoding ascii      
        }        
    }
    
    # Update Report Permissions
    # Init Arrays for this folder
    $folderPolicyArray = New-Object System.Collections.ArrayList

    # Build up the Policies by User
    $UniqueUsers = $reportPolicies | sort UserName -Unique | select Username
    foreach ($UniqueUser in $UniqueUsers)
    {

        # Skip restoring permissions for departed/inactive users
        if (!($ActiveUsers | where-object {$_.Username -in $UniqueUser.UserName}) -and $UniqueUser.UserName -notin ('BUILTIN\Administrators','NT AUTHORITY\Authenticated Users')) {continue}

        $pol = New-Object ($PolicyDataType)
        $pol.GroupUserName = $UniqueUser.UserName

        # Build overly complex Roles Object
        $roleArray = New-Object System.Collections.ArrayList
        $rolesforthisUser = ($reportPolicies | where-object {$_.UserName -eq $UniqueUser.UserName}).Rolename
        foreach($roleName in $rolesforthisUser)
        {
            # Skip until Microsoft explains why this Role is missing from SSRS 2017
            if ($roleName -eq 'Subscription Manager'){continue}

            $role = New-Object ($RoleDataType)
            $Role.Name = $roleName
            $role.Description=''
            $roleArray.add($role) | out-null
        }
    
        $pol.Roles = $roleArray
        $folderPolicyArray.add($pol) | Out-null
    }

    # Apply the policy using SOAP
    if ($reportPolicyRoot -eq $true)
    {
        try
        {
            $PolicyID = $rs.SetPolicies($reportPath,$folderPolicyArray)
        }
        catch
        {
            Write-Output('Error Setting Policies on Report [{0}]' -f $error[0])
        }
    }

    # Set Inheritance OFF when PolicyRoot=1
    if ($reportPolicyRoot -eq $true)
    {
        try
        {
            #$InheritID = $rs.InheritParentSecurity($reportPath)
            $sqlCMDUpdatePolicyRoot=
            "
            update
                [ReportServer].[dbo].[Catalog]
            set
                PolicyRoot=1
            where
                ItemID = '$NewItemID'
            "
            $SQLStatus = Connect-SQLServerExecuteNonQuery -SQLInstance $SQLInstance -Database 'ReportServer' -SQLExec $sqlCMDUpdatePolicyRoot -ErrorAction Stop
            
        }
        catch
        {
            Write-Output('Error Setting PolicyRoot on Report [{0}]' -f $error[0])
        }
    }

}



# -----------------
# 5) Subscriptions
# -----------------
Write-Output('Restoring Subscriptions...')
try
{
    $Subscriptions = Import-Clixml -Path "$fullfolderPathSUB\SubscriptionsSOAP.xml"
}
catch
{
    Throw('Failed to load Subscriptions CLIXML file [{0}]' -f "$fullfolderPathSUB\SubscriptionsSOAP.xml")
}

foreach($Sub in $Subscriptions)
{
    # Connect to SOAP Service    
    $rs = New-WebServiceProxy -Uri $SOAPAPIURL -UseDefaultCredential;
    $type = $rs.GetType().Namespace

    $ExtensionSettingsDataType = ($type + '.ExtensionSettings')
    $ActiveStateDataType = ($type + '.ActiveState')
    $ParmValueDataType = ($type + '.ParameterValue')

    $extSettings = New-Object ($ExtensionSettingsDataType)
    $ReportParameters = New-Object ($ParmValueDataType)

    # Function Call parameters setup
    $rptExtensionArray = @()
    $rptParamArray = @()

    # Get more Report parameters
    $report = $sub.Report
    $desc = $Sub.Description
    $event = $Sub.EventType
    $extSettings.Extension = $sub.ExtensionSettings.Extension

    # Build up the Extension Parameters Block
    $xExtParams = $Sub.ExtensionSettings.ParameterValues
    foreach ($p in $xExtParams) {
    	$param = New-Object ($ParmValueDataType)
    	$param.Name = $p.Name
    	$param.Value = $p.Value
    	$rptExtensionArray += $param
    }    
    $extSettings.ParameterValues = $rptExtensionArray
    
    # Build up the Report Parameters block
    $ReportParameters= $sub.ReportParameters
    foreach ($rp in $ReportParameters) {
        $rparam = New-Object ($ParmValueDataType)
    	$rparam.Name = $rp.Name
    	$rparam.Value = $rp.Value
    	$rptParamArray += $rparam
    }
    $ReportParameters = $rptParamArray

    
    # If the Sub uses its own schedule, Get the schedule from the XML Definition 
    # Else the Schedule definition is a GUID pointing to a shared schedule which we just restored above
    if ($Sub.Schedule -match("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$") -eq $true)
    {
        # Lookup real Schedule XML Fragment from the Shared Schedule
        $sharedScheduleName = $SharedSchedules | where-object {$_.ScheduleID -eq $Sub.Schedule} | select -ExpandProperty Name
        Write-Output('Grabbing ScheduleXML from Shared Schedule [{0}]' -f $sharedScheduleName)
        
        # Get New ScheduleID using Name match
        $sqlCMDNewSkedID=
        "
        SELECT ScheduleID FROM Schedule WHERE [Name]='$sharedScheduleName'
        "

        # New up needed objects
        $SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=ReportServer;Integrated Security=SSPI;"
        $DataSet = New-Object System.Data.DataSet
        $Connection = New-Object System.Data.SqlClient.SqlConnection
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $Connection.ConnectionString = $SQLConnectionString
        $SqlCmd.CommandText = $sqlCMDNewSkedID
        $SqlCmd.Connection = $Connection
        $SqlCmd.CommandTimeout=0
        $SqlAdapter.SelectCommand = $SqlCmd

    
        # Insert results into Dataset table
        $SqlAdapter.Fill($DataSet) |out-null
        if ($DataSet.Tables.Count -ne 0) 
        {
            $SKIDResults = $DataSet.Tables[0]
        }
        else
        {
            $SKIDResults =$null
        }

        # Close connection to sql server
        $Connection.Close()

        $scheduleXml = $SKIDResults.ScheduleID
    }
    else
    {
        $scheduleXml = $Sub.Schedule
    }
    

    # Get Report Parameters from XML Fragment
    $ReportParameters = $sub.ReportParameters

    # Call the WebService
    try
    {
        $subscriptionID = $rs.CreateSubscription($report, $extSettings, $desc, $event, $scheduleXml, $ReportParameters)
        Write-Output("Created Subscription on report [{0}] ID: {1}" -f $report,$subscriptionID)
    }
    catch
    {
        $report+' - '+$desc  | out-file -FilePath "$InputObjectsPath\SubscriptionImportErrors.txt" -Append -Encoding ascii
        Write-Output("Error: {0}: `r`n" -f $_.Exception.Message) | out-file -FilePath "$InputObjectsPath\SubscriptionImportErrors.txt" -Append -Encoding ascii
    }

    $rs = $null
}



Write-Output("`r`n")
Write-Output("PLEASE NOTE: You MUST use the [Report Server Configuration Manager] to RESTORE")
Write-Output("the saved Encryption Key before everything will work correctly")
Write-Output("The DataSource's Saved Credentials are encrypted with this KEY")
Write-Output("The Key Password is in the companion file [Encryption\SSRS_Encryption_Key_Password.txt]")

