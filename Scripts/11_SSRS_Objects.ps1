<#
.SYNOPSIS
    Gets the SQL Server Reporting Services objects on the target server
	
.DESCRIPTION
   Writes the SSRS Objects out to the "11 - SSRS" folder   
   Objects written include:
   RDL files
   Timed Subscriptions
   RSreportserver.config file
   Encryption Keys   
   
.EXAMPLE
    11_SSRS_Objects.ps1 localhost
	
.EXAMPLE
    11_SSRS_Objects.ps1 server01 sa password


.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK

	
#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


#  Script Name
Write-Host  -f Yellow -b Black "11 - SSRS Objects"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./11_SSRS_Objects.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ/SQL Auth machine)"
    set-location $BaseFolder
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
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

		# SQLCMD.EXE Method
        #$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
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
		$SqlAdapter.Fill($DataSet) | out-null

		# Close connection to sql server
		$Connection.Close()
		$results = $DataSet.Tables[0].Rows[0]

		# SQLCMD.EXE Method
    	#$results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
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


# Create some CSS for help in column formatting during HTML exports
$myCSS = 
"
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


set-location $BaseFolder

# Create output folder
$folderPath = "$BaseFolder\$sqlinstance"
if(!(test-path -path $folderPath))
{
    mkdir $folderPath | Out-Null
}

$mySQL = 
"
    --The first CTE gets the content as a varbinary(max)
    --as well as the other important columns for all reports,
    --data sources and shared datasets.
    WITH ItemContentBinaries AS
    (
      SELECT
         ItemID,
         ParentID,
         Name,
         [Type],
         CASE Type
           WHEN 2 THEN 'Report'
           WHEN 5 THEN 'Data Source'
           WHEN 7 THEN 'Report Part'
           WHEN 8 THEN 'Shared Dataset'
           ELSE 'Other'
         END AS TypeDescription,
         CONVERT(varbinary(max),Content) AS Content
      FROM ReportServer.dbo.Catalog
      WHERE Type IN (2,5,7,8)
    ),

    --The second CTE strips off the BOM if it exists...
    ItemContentNoBOM AS
    (
      SELECT
         ItemID,
         ParentID,
         Name,
         [Type],
         TypeDescription,
         CASE
           WHEN LEFT(Content,3) = 0xEFBBBF
             THEN CONVERT(varbinary(max),SUBSTRING(Content,4,LEN(Content)))
           ELSE
             Content
         END AS Content
      FROM ItemContentBinaries
    )

    --The outer query gets the content in its varbinary, varchar and xml representations...
    SELECT
       ItemID,
       ParentID,
       Name,
       [Type],
       TypeDescription,
       Content, --varbinary
       CONVERT(varchar(max),Content) AS ContentVarchar, --varchar
       CONVERT(xml,Content) AS ContentXML --xml
    FROM ItemContentNoBOM
    order by 2
"

$sqlToplevelfolders = "
SELECT [ItemId],[ParentID],[Path]
  FROM [ReportServer].[dbo].[Catalog]
  where Parentid is not null and [Type] = 1  
"



# initialize arrays
$Packages = @()
$toplevelfolders = @()
$skeds = @()

# Connect correctly
$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
    Write-Output "Using SQL Auth"
    $serverauth = "sql"

	# First, see if the SSRS Database exists
	$exists = $FALSE
	
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
    $server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
    $server.ConnectionContext.Password=$mypass

    if ( $null -ne $server.Databases["ReportServer"] ) { $exists = $true } else { $exists = $false }

	if ($exists -eq $FALSE)
    {
        Write-Output "SSRS Database not found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\11 - SSRS Catalog - Not found or cant connect.txt"
        Set-Location $BaseFolder
        exit
    }


    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySQL
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$Packages = $DataSet.Tables[0].Rows

    #$Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $mySQL

    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlToplevelfolders
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$toplevelfolders = $DataSet.Tables[0].Rows
    
    #$toplevelfolders = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance  -Username $myuser -Password $mypass  -Query $sqlToplevelfolders

}
else
{
    Write-Output "Using Windows Auth"

	# See if the SSRS Database Exists
	$exists = $FALSE
	   
	# Get reference to database instance
	$server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLInstance
	
    if ( $null -ne $server.Databases["ReportServer"] ) { $exists = $true } else { $exists = $false }   
	
	if ($exists -eq $FALSE)
    {
        Write-Output "SSRS Catalog not found on $SQLInstance"
        echo null > "$BaseFolder\$SQLInstance\11 - SSRS Catalog - Not found or cant connect.txt"
        set-location $BaseFolder
        exit
    }


   	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySQL
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$Packages = $DataSet.Tables[0].Rows

    #$Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $mySQL

   	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlToplevelfolders
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$toplevelfolders = $DataSet.Tables[0].Rows

    #$toplevelfolders = Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $sqlToplevelfolders

}

# Create output folders
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\11 - SSRS"
$fullfolderPathRDL = "$BaseFolder\$sqlinstance\11 - SSRS\RDL"
$fullfolderPathSUB = "$BaseFolder\$sqlinstance\11 - SSRS\Timed Subscriptions"
$fullfolderPathKey = "$BaseFolder\$sqlinstance\11 - SSRS\Encryption Key"
$fullfolderPathSecurity = "$BaseFolder\$sqlinstance\11 - SSRS\Folder Permissions"

if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

if(!(test-path -path $fullfolderPathRDL))
{
    mkdir $fullfolderPathRDL | Out-Null
}

if(!(test-path -path $fullfolderPathSUB))
{
    mkdir $fullfolderPathSUB | Out-Null
}

if(!(test-path -path $fullfolderPathKey))
{
    mkdir $fullfolderPathKey | Out-Null
}

if(!(test-path -path $fullfolderPathSecurity))
{
    mkdir $fullfolderPathSecurity | Out-Null
}
	
# --------
# 1) RDL
# --------
Write-Output "Writing RDL.."

# Create Output Folder Structure to mirror the SSRS ReportServer Catalog and dump the RDL into the respective folders
foreach ($tlfolder in $toplevelfolders)
{
    # Only Script out the Items for this Folder
    # Create Folder Structure
    $myNewStruct = $fullfolderPathRDL+$tlfolder.Path
    # Fixup forward slashes
    $myNewStruct = $myNewStruct.replace('/','\')
    if(!(test-path -path $myNewStruct))
    {
        mkdir $myNewStruct | Out-Null
    }

    # Only Script out the Reports in this Folder
    $myParentID = $tlfolder.ItemID
    Foreach ($pkg in $Packages)
    {
        if ($pkg.ParentID -eq $myParentID)
        {

            # Get the Report ID, Name
            $myItemID = $pkg.ItemID
            $pkgName = $Pkg.name

            # Report RDL
            if ($pkg.Type -eq 2)
            {    
                #Export                
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.rdl"
            }

            # Data Source
            if ($pkg.Type -eq 5)
            {    

                # Export
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.dsrc.txt"
            }

            # Shared Dataset
            if ($pkg.Type -eq 8)
            {    

                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.shdset.txt"
            }

            # Other Types include
            # 3 - File/Resource
            # 4 - Linked Report
            # 6 - Model
            # 7 - 
            # 9 - 

            

        } # Parent
    } # Items in this folder


}


# ------------------------
# 2) SSRS Configuration
# ------------------------
Write-Output "Writing SSRS Settings to file..."
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

[int]$wmi1 = 0
try 
{
    $junk = get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v10\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
    if ($?)
    {
        $wmi1 = 10
        Write-Output "Found SSRS v10 (2008)"
    }
    else
    {
        #Write-Output "NOT v10"
    }
}
catch
{
    #Write-Output "NOT v10"
}


if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v11\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 11
            Write-Output "Found SSRS v11 (2012)"
        }
        else
        {
            #Write-Output "NOT v11"
        }
    }
    catch
    {
        #Write-Output "NOT v11"
    }
}

if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v12\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 12
            Write-Output "Found SSRS v12 (2014)"
        }
        else
        {
            #Write-Output "NOT v12"
        }
    }
    catch
    {
        #Write-Output "NOT v12"
    }
}

# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

# -------------------------
# 3) RSReportServer.config File
# -------------------------
# https://msdn.microsoft.com/en-us/library/ms157273.aspx

Write-Output "Saving RSReportServer.config file..."

# 2008
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2008 R2
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10_50.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS10_50.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2012
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS11.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS11.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2014
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS12.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS12.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# -----------------------
# 4) Database Encryption Key
# -----------------------
Write-Output "Backup SSRS Encryption Key..."
Write-Output ("WMI found SSRS version {0}" -f $wmi1)

if ($wmi1 -eq 10)
{
    Write-Output "SSRS 2008 - cant access Encryption key from WMI. Please use rskeymgmt.exe on server to export the key"
    New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
    Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
}

# We use WMI against 2012/2014 SSRS Servers
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# 2012
if ($wmi1 -eq 11)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\microsoft\sqlserver\reportserver\rs_mssqlserver\v11\admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
        if ($?)
        {
            $result = $serverClass.BackupEncryptionKey("SomeNewSecurePassword$!")
            $stream = [System.IO.File]::Create("$fullfolderPathKey\ssrs_master_key.snk", $result.KeyFile.Length);
            $stream.Write($result.KeyFile, 0, $result.KeyFile.Length);
            $stream.Close();
        }
        else
        {
            New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
            Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
            Write-Output "Error Connecting to WMI for config file (v11)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii        
        Write-Output "Error Connecting to WMI for config file (v11) 2"
    }
}

# 2014
if ($wmi1 -eq 12)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\microsoft\sqlserver\reportserver\rs_mssqlserver\v12\admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
        if ($?)
        {
            $result = $serverClass.BackupEncryptionKey("SomeNewSecurePassword$!")
            $stream = [System.IO.File]::Create("$fullfolderPathKey\ssrs_master_key.snk", $result.KeyFile.Length);
            $stream.Write($result.KeyFile, 0, $result.KeyFile.Length);
            $stream.Close();
        }
        else
        {
            New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
            Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii            
            Write-Output "Error Connecting to WMI for config file (v12)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
        Write-Output "Error Connecting to WMI for config file (v12) 2"
    }
}

# Reset default PS error handler - cause WMI error trapping sucks
$ErrorActionPreference = $old_ErrorActionPreference 

# ---------------------
# 5) Timed Subscriptions
# ---------------------
# If Report is using a Timed Subscription Schedule, Export it

$myRDLSked = 
"
select 
	distinct s.ScheduleID as 'SchID',
	c.ItemId as 'ReportID',
	c.[path] as 'Folder',
	c.[name] as 'Report',
	s.state as 'State',
	case 
		when s.RecurrenceType=6 then 'Week of Month'
		when s.RecurrenceType=5 then 'Monthly'
		when s.RecurrenceType=4 then 'Daily'
		when s.RecurrenceType=2 then 'Minute'
		when s.RecurrenceType=1 then 'AdHoc'
	end as 'RecurrenceType',
	CONVERT(VARCHAR(8), s.StartDate, 108) as 'RunTime',
	coalesce(s.WeeksInterval,'') as 'Weeks_Interval',
	coalesce(s.MinutesInterval,'') as 'Minutes_Interval',
	case when s.[month] & 1 = 1 then 'X' else '' end as 'Jan',
	case when s.[month] & 2 = 2 then 'X' else '' end as 'Feb',
	case when s.[month] & 4 = 4 then 'X' else '' end as 'Mar',
	case when s.[month] & 8 = 8 then 'X' else '' end as 'Apr',
	case when s.[month] & 16 = 16 then 'X' else '' end as 'May',
	case when s.[month] & 32 = 32 then 'X' else '' end as 'Jun',
	case when s.[month] & 64 = 64 then 'X' else '' end as 'Jul',
	case when s.[month] & 128 = 128 then 'X' else '' end as 'Aug',
	case when s.[month] & 256 = 256 then 'X' else '' end as 'Sep',
	case when s.[month] & 512 = 512 then 'X' else '' end as 'Oct',
	case when s.[month] & 1024 = 1024 then 'X' else '' end as 'Nov',
	case when s.[month] & 2048 = 2048 then 'X' else '' end as 'Dec',
	case s.MonthlyWeek
		when 1 then 'First'
		when 2 then 'Second'
		when 3 then 'Third'
		when 4 then 'Fourth'
		when 5 then 'Last'
	else ''
	End AS 'Week_of_Month',
	case when s.daysofweek & 1 = 1 then 'Sun' else '' end as 'Sun',
	case when s.daysofweek & 2 = 2 then 'Mon' else '' end as 'Mon',
	case when s.daysofweek & 4 = 4 then 'Tue' else '' end as 'Tue',
	case when s.daysofweek & 8 = 8 then 'Wed' else '' end as 'Wed',
	case when s.daysofweek & 16 = 16 then 'Thu' else '' end as 'Thu',
	case when s.daysofweek & 32 = 32 then 'Fri' else '' end as 'Fri',
	case when s.daysofweek & 64 = 64 then 'Sat' else '' end as 'Sat',
	DATEPART(hh,s.StartDate) as 'RunHour',
	case when DATEPART(hh,s.StartDate) =0 then 'X' else '' end as '00Z',
	case when DATEPART(hh,s.StartDate) =1 then 'X' else '' end as '01Z',
	case when DATEPART(hh,s.StartDate) =2 then 'X' else '' end as '02Z',
	case when DATEPART(hh,s.StartDate) =3 then 'X' else '' end as '03Z',
	case when DATEPART(hh,s.StartDate) =4 then 'X' else '' end as '04Z',
	case when DATEPART(hh,s.StartDate) =5 then 'X' else '' end as '05Z',
	case when DATEPART(hh,s.StartDate) =6 then 'X' else '' end as '06Z',
	case when DATEPART(hh,s.StartDate) =7 then 'X' else '' end as '07Z',
	case when DATEPART(hh,s.StartDate) =8 then 'X' else '' end as '08Z',
	case when DATEPART(hh,s.StartDate) =9 then 'X' else '' end as '09Z',
	case when DATEPART(hh,s.StartDate) =10 then 'X' else '' end as '10Z',
	case when DATEPART(hh,s.StartDate) =11 then 'X' else '' end as '11Z',
	case when DATEPART(hh,s.StartDate) =12 then 'X' else '' end as '12Z',
	case when DATEPART(hh,s.StartDate) =13 then 'X' else '' end as '13Z',
	case when DATEPART(hh,s.StartDate) =14 then 'X' else '' end as '14Z',
	case when DATEPART(hh,s.StartDate) =15 then 'X' else '' end as '15Z',
	case when DATEPART(hh,s.StartDate) =16 then 'X' else '' end as '16Z',
	case when DATEPART(hh,s.StartDate) =17 then 'X' else '' end as '17Z',
	case when DATEPART(hh,s.StartDate) =18 then 'X' else '' end as '18Z',
	case when DATEPART(hh,s.StartDate) =19 then 'X' else '' end as '19Z',
	case when DATEPART(hh,s.StartDate) =20 then 'X' else '' end as '20Z',
	case when DATEPART(hh,s.StartDate) =21 then 'X' else '' end as '21Z',
	case when DATEPART(hh,s.StartDate) =22 then 'X' else '' end as '22Z',
	case when DATEPART(hh,s.StartDate) =23 then 'X' else '' end as '23Z'

FROM 
	[ReportServer].[dbo].[Schedule] S	            
inner join 
	[ReportServer].[dbo].[ReportSchedule]  I
on 
	S.ScheduleID = I.ScheduleID

inner join 
	[ReportServer].[dbo].[Catalog] c
on 
	I.reportID = C.ItemID
						
order by DATEPART(hh,s.StartDate), 3, 4
"

if ($serverauth -eq "win")
{

	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $myRDLSked
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$Skeds = $DataSet.Tables[0].Rows

    #$Skeds =  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $myRDLSked
}
else
{

    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $myRDLSked
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$Skeds = $DataSet.Tables[0].Rows

    #$Skeds =  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $myRDLSked
}


# CSS file
if(!(test-path -path "$fullfolderPathSUB\HTMLReport.css"))
{
    $myCSS | out-file "$fullfolderPathSUB\HTMLReport.css" -Encoding ascii    
}


Write-Output "Visual Timed Subscriptions..."
$RunTime = Get-date

$HTMLFileName = "$fullfolderPathSUB\Visual_Subscription_Schedule.html"


$Skeds | select Folder, Report, State, RecurrenceType, RunTime, Weeks_Interval, Minutes_Interval, `
Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec, `
Week_of_Month, Sun, Mon, Tue, Wed, Thu, Fri, Sat, RunHour,  `
00Z, 01Z, 02Z, 03Z, 04Z, 05Z, 06Z, 07Z, 08Z, 09Z, 10Z, 11Z, 12Z, 13Z, 14Z, 15Z, 16Z, 17Z, 18Z, 19Z, 20Z, 21Z, 22Z, 23Z `
| ConvertTo-Html -PostContent "<h3>Ran on : $RunTime</h3>" -CSSUri "HtmlReport.css"| Set-Content $HTMLFileName

# Script out the Create Subscription Commands
Write-Output "Timed Subscription Create commands..."
$mySubs = 
"
USE [ReportServer];

select 
	'exec CreateSubscription @id='+char(39)+convert(varchar(40),S.[SubscriptionID])+char(39)+', '+
	'@Locale=N'+char(39)+S.[Locale]+char(39)+', '+
	'@Report_Name=N'+char(39)+R.Name+char(39)+', '+
	'@ReportZone='+char(39)+ convert(varchar,S.[ReportZone])+char(39)+', '+
	'@OwnerSid='+char(39)+ '0x'+convert(varchar(max),Owner.[Sid],2)+char(39)+', '+
	'@OwnerName=N'+char(39)+ SUSER_SNAME(Owner.[Sid])+char(39)+', '+
	'@OwnerAuthType='+char(39)+ convert(varchar,Owner.[AuthType])+char(39)+', '+
	'@DeliveryExtension=N'+char(39)+S.[DeliveryExtension]+char(39)+', '+
	'@InactiveFlags='+char(39)+ convert(varchar,S.[InactiveFlags])+char(39)+', '+
	'@ExtensionSettings=N'+char(39)+ replace(convert(varchar(max),S.[ExtensionSettings]),char(39),char(39)+char(39))+char(39)+', '+
	'@ModifiedBySid='+char(39)+ '0x'+convert(varchar(max),Modified.[Sid],2)+char(39)+', '+
	'@ModifiedByName=N'+char(39)+isnull(SUSER_SNAME(Modified.[Sid]),'')+char(39)+', '+
	'@ModifiedByAuthType='+char(39)+ convert(varchar,Modified.AuthType)+char(39)+', '+
	'@ModifiedDate='+char(39)+ convert(varchar, S.[ModifiedDate],120)+char(39)+', '+
	'@Description=N'+char(39)+S.[Description]+char(39)+', '+
	'@LastStatus=N'+char(39)+S.[LastStatus]+char(39)+', '+
	'@EventType=N'+char(39)+S.[EventType]+char(39)+', '+
	'@MatchData=N'+char(39)+ replace(convert(varchar(max),S.[MatchData]),char(34),char(39)+char(39))+char(39)+', '+
	'@Parameters=N'+char(39)+ replace(convert(varchar(max),S.[Parameters]),char(39),char(39)+char(39))+char(39)+', '+
	'@DataSettings=N'+char(39)+ replace(convert(varchar(max),isnull(S.[DataSettings],'')),char(39),char(39)+char(39))+char(39)+', '+
	'@Version='+char(39)+ convert(varchar,S.[Version])+char(39) as 'ExecString'
from
    [Subscriptions] S inner join [Catalog] CAT on S.[Report_OID] = CAT.[ItemID]
    inner join [Users] Owner on S.OwnerID = Owner.UserID
    inner join [Users] Modified on S.ModifiedByID = Modified.UserID
    left outer join [SecData] SD on CAT.PolicyID = SD.PolicyID AND SD.AuthType = Owner.AuthType
    left outer join [ActiveSubscriptions] A on S.[SubscriptionID] = A.[SubscriptionID]
	inner join [ReportServer].[dbo].[Catalog] R on S.Report_OID = r.ItemID;
"

if ($serverauth -eq "win")
{
	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySubs
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$SubCommands = $DataSet.Tables[0].Rows

    #$SubCommands =  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $mySubs
}
else
{
    # .NET Method
	# Open connection and Execute sql against server
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $mySubs
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$SubCommands = $DataSet.Tables[0].Rows

    #$SubCommands =  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $mySubs
}

# Script Out
if ($SubCommands)
{    
    New-Item "$fullfolderPathSUB\Timed_Subscriptions.sql" -type file -force  |Out-Null

    foreach ($TSub in $SubCommands)
    {        
        $TSub.ExecString | out-file -FilePath "$fullfolderPathSUB\Timed_Subscriptions.sql" -append -encoding ascii -width 500000
    }

}



# --------------------
# 6) Folder Permissions
# --------------------
# http://stackoverflow.com/questions/6600480/ssrs-determine-report-permissions-via-reportserver-database-tables
#
# Item-level role assignments
# System-level role assignments
# Predefined roles - https://msdn.microsoft.com/en-us/library/ms157363.aspx
#  Content Manager Role
#  Publisher Role 
#  Browser Role
#  Report Builder Role
#  My Reports Role
#  System Administrator Role
#  System User Role

$sqlSecurity = "
Use ReportServer;
select E.Path, E.Name, C.UserName, D.RoleName
from dbo.PolicyUserRole A
   inner join dbo.Policies B on A.PolicyID = B.PolicyID
   inner join dbo.Users C on A.UserID = C.UserID
   inner join dbo.Roles D on A.RoleID = D.RoleID
   inner join dbo.Catalog E on A.PolicyID = E.PolicyID
order by 1
"


# Get Permissions
# Error trapping off for webserviceproxy calls
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
    Write-Output "Using SQL Auth"

	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlSecurity
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$sqlPermissions = $DataSet.Tables[0].Rows


    #$sqlPermissions = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $sqlSecurity -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
}
else
{
    Write-Output "Using Windows Auth"

	# .NET Method
	# Open connection and Execute sql against server using Windows Auth
	$DataSet = New-Object System.Data.DataSet
	$SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	$Connection = New-Object System.Data.SqlClient.SqlConnection
	$Connection.ConnectionString = $SQLConnectionString
	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $sqlSecurity
	$SqlCmd.Connection = $Connection
	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd
    
	# Insert results into Dataset table
	$SqlAdapter.Fill($DataSet) | out-null

	# Close connection to sql server
	$Connection.Close()
	$sqlPermissions = $DataSet.Tables[0].Rows

    #$sqlPermissions = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $sqlSecurity -QueryTimeout 10 -erroraction SilentlyContinue
}


# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 



$myCSS | out-file "$fullfolderPathSecurity\HTMLReport.css" -Encoding ascii


$sqlPermissions | select Path, Name, UserName, RoleName  | ConvertTo-Html -PostContent "<h3>Ran on : $RunTime</h3>" -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPathSecurity\HtmlReport.html"


# Return to Base
set-location $BaseFolder

