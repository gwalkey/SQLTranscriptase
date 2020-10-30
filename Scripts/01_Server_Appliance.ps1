<#
.SYNOPSIS
    Gets the Hardware/Software config of the targeted SQL server
	
.DESCRIPTION
    This script lists the Hardware and Software installed on the targeted SQL Server
    CPU, RAM, DISK, Installation and Backup folders, SQL Version, Edition, Patch Levels, Cluster/HA
	
.EXAMPLE
    01_Server_Appliance.ps1 localhost
	
.EXAMPLE
    01_Server_Appliance.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK
	https://github.com/gwalkey
	
#>

[CmdletBinding()]
Param(
    [parameter(Position=0,mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$SQLInstance='localhost',

    [parameter(Position=1,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,50)]
    [string]$myuser,

    [parameter(Position=2,mandatory=$false,ValueFromPipeline)]
    [ValidateLength(0,50)]
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
[string]$BaseFolder = (get-location).path
Write-Host -f Yellow -b Black "01 - Server Appliance"
Write-Output("Server: [{0}]" -f $SQLInstance)

# Get servername if parameter contains a SQL named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

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
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Appliance"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}

# New UP SMO Server Object
if ($serverauth -eq "win")
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}
else
{
    try
    {
        $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
        $srv.ConnectionContext.LoginSecure=$false
        $srv.ConnectionContext.set_Login($myuser)
        $srv.ConnectionContext.set_Password($mypass)    
    }
    catch
    {
        Write-Output "Cannot Create an SMO Object"
        Write-Output("Error is: {0}" -f $error[0])
        exit
    }
}


# Dump Initial Server info to output file
$fullFileName = $fullfolderPath+"\01_Server_Appliance.txt"
New-Item $fullFileName -type file -force | Out-Null
Add-Content -Value "Server Hardware and Software Capabilities for $SQLInstance `r`n" -Path $fullFileName -Encoding Ascii


# Get Server Uptime
if ($ver -eq 9)
{
    $mysql11 = 
    "
    SELECT DATEADD(ms,-sample_ms,GETDATE()) AS sqlserver_start_time FROM sys.dm_io_virtual_file_stats(1,1);
    "
}
else
{
    $mysql11 =
    "
    SELECT sqlserver_start_time FROM sys.dm_os_sys_info;
    "
}

# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults11 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql11
}
else
{
    $sqlresults11 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql11 -User $myuser -Password $mypass
}

if ($sqlresults11 -ne $null)
{
    "Engine Start Time: " + $sqlresults11.sqlserver_start_time+"`r`n" | out-file $fullFileName -Encoding ascii -Append  
}
else
{
    Write-Output "Cannot determine Server Uptime"
}



# Get SQL Engine Installation Date
$mysql12 = 
"
USE [master];

SELECT	MIN([crdate]) as 'column1'
FROM	[sys].[sysdatabases]
WHERE	[dbid] > 4 --not master, tempdb, model, msdb
;
"

# Connect correctly
if ($serverauth -eq "win")
{
    $sqlresults12 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql12
}
else
{
    $sqlresults12 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql12 -User $myuser -Password $mypass
}


if ($sqlresults12 -ne $null) {$myCreateDate = $sqlresults12.column1} else {$myCreateDate ='Unknown'}


# Get SQL Server Config Settings using SMO

$mystring =  "SQL Server Name: " +$srv.Name 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Server Create Date: " +$MyCreateDate
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Version: " +$srv.Version 
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Edition: " +$srv.EngineEdition
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Build Number: " +$srv.BuildNumber
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product: " +$srv.Product
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Product Level: " +$srv.ProductLevel
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Processors: " +$srv.Processors
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Max Physical Memory MB: " +$srv.PhysicalMemory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Physical Memory in Use MB: " +$srv.PhysicalMemoryUsageinKB
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB Path: " +$srv.MasterDBPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL MasterDB LogPath: " +$srv.MasterDBLogPath
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Backup Directory: " +$srv.BackupDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Shared Dir: " +$srv.InstallSharedDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Install Data Dir: " +$srv.InstallDataDirectory
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Service Account: " +$srv.ServiceAccount
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Collation: " +$srv.Collation
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Security Model: " +$srv.LoginMode
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols - Named Pipes: " +$srv.NamedPipesEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols - TCPIP: " +$srv.TcpEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Browser Start Mode: " +$srv.BrowserStartMode
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "SQL Protocols: " + ($srv.endpoints | select Parent, Name, Endpointtype, EndpointState, ProtocolType |format-table| out-string)
$mystring | out-file $fullFileName -Encoding ascii -Append



# TempDB Location
# Get SQL Engine Installation Date
$mysql13 = 
"
USE [tempdb]
SELECT *  FROM [sys].[database_files] ORDER BY file_id;
"

# Connect correctly
if ($serverauth -eq "win")
{
    $sqlresults13 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql13
}
else
{
    $sqlresults13 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql13 -User $myuser -Password $mypass
}


if ($sqlresults13 -ne $null) 
{
    "TempDB Files: " | out-file $fullFileName -Encoding ascii -Append

    foreach($File in $sqlresults13)
    {
        Write-Output("ID:{0}, Type:{1}, Name: {2}, FileName:{3}" -f $File.file_id, $file.type_desc, $File.name, $file.physical_name) |out-file $fullFileName -Encoding ascii -Append
    }
}

" " | out-file $fullFileName -Encoding ascii -Append

# Windows
$mystring =  "OS Version: " +$srv.OSVersion
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is Clustered: " +$srv.IsClustered
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Is HADR: " +$srv.IsHadrEnabled
$mystring | out-file $fullFileName -Encoding ascii -Append

$mystring =  "OS Platform: " +$srv.Platform
$mystring | out-file $fullFileName -Encoding ascii -Append


# OS Info Via WMI
try
{

    $myWMI = Get-WmiObject -class Win32_OperatingSystem  -ComputerName $WinServer -ErrorAction SilentlyContinue | select Name, BuildNumber, BuildType, CurrentTimeZone, InstallDate, SystemDrive, SystemDevice, SystemDirectory

    Write-Output ("OS Host Name: {0}" -f $myWMI.Name ) | out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS BuildNumber: {0}" -f $myWMI.BuildNumber )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS Buildtype: {0}" -f $myWMI.BuildType )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS CurrentTimeZone: {0}" -f $myWMI.CurrentTimeZone)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS InstallDate: {0}" -f $myWMI.InstallDate)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDrive: {0}" -f $myWMI.SystemDrive)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDevice: {0}" -f $myWMI.SystemDevice)| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("OS SystemDirectory:{0}" -f $myWMI.SystemDirectory)| out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting OS specs via WMI - WMI/firewall issue?"| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting OS specs via WMI - WMI/firewall issue?"
}

" " | out-file $fullFileName -Encoding ascii -Append

# ---------------
# Hardware
# ---------------
# Motherboard
# Turn off default Error Handler for WMI
try
{
    $myWMI = Get-WmiObject  -class Win32_Computersystem -ComputerName $WinServer -ErrorAction SilentlyContinue | select manufacturer
    Write-Output ("HW Manufacturer: {0}" -f $myWMI.Manufacturer ) | out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting Hardware specs via WMI - WMI/firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting Hardware specs via WMI - WMI/firewall issue? "
}


# Proc, CPUs, Cores
try
{

    $myWMI = Get-WmiObject -class Win32_processor -ComputerName $WinServer -ErrorAction SilentlyContinue | select Name, NumberOfLogicalProcessors, NumberOfCores
    Write-Output ("HW Processor: {0}" -f $myWMI.Name ) | out-file $fullFileName -Encoding ascii -Append
    Write-Output ("HW CPUs: {0}" -f $myWMI.NumberOfLogicalProcessors )| out-file $fullFileName -Encoding ascii -Append
    Write-Output ("HW Cores: {0}" -f $myWMI.NumberOfCores )| out-file $fullFileName -Encoding ascii -Append

}
catch
{
    Write-output "Error getting CPU specs via WMI - WMI/Firewall issue? "| out-file $fullFileName -Encoding ascii -Append
    Write-Output "Error getting CPU specs via WMI - WMI/Firewall issue? "
}

" " | out-file $fullFileName -Encoding ascii -Append


# Get PowerPlan
<#
a75f1671-ff77-4626-8f23-c6d4095e1396  (Power Saver)
381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)
8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  (High performance)
a42635e8-c082-4fbf-9bc1-6b12576771ab  (Ultimate Performance)
#>
try
{
    try
    {
        $PP = Get-WmiObject -Class win32_powerplan -Namespace root\cimv2\power -CN c0sql1 -Filter "isActive='true'"
        $mystring41 = $pp.elementName
    }
    catch
    {
        Write-host('Error getting Power Profile using WMI')
        $mystring41=''
    }
    if (!($mystring41 -match "High" -or $mystring41 -match "Ulti")) 
    {
        Write-output ("PowerPlan is *not optimal for SQL Server *")| out-file $fullFileName -Encoding ascii -Append
        Write-output ("{0}" -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
        Write-output ("Run this to fix: powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
    }
    else
    {
        Write-output ("PowerPlan: {0} " -f $mystring41)| out-file $fullFileName -Encoding ascii -Append
    }
}
catch
{
    Write-Output("Error getting PowerPlan using powercfg.exe ")
    Write-Output("Error getting PowerPlan using powercfg.exe ")| out-file $fullFileName -Encoding ascii -Append
}


" " | out-file $fullFileName -Encoding ascii -Append


# Get PowerShell Version
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

if ($SQLInstance -eq 'localhost')
{
    $MyPSVersion = (Get-Host).Version
}
else
{
    if ($myuser.Length -gt 0 -and $mypass.Length -gt 0)
    {        
        $MyPSVersion = $null
    }
    else
    {
        $MyPSVersion = Invoke-Command -ComputerName $WinServer -ScriptBlock {$PSVersionTable.PSVersion}
    }
}
if ($MyPSVersion -ne $null)
{    
    $mystring =  "Powershell Version: " +$myPSVersion
}
else
{
    $mystring =  "Powershell Version: Unknown"
}
$mystring+"`r`n" | out-file $fullFileName -Encoding ascii -Append

$ErrorActionPreference = $old_ErrorActionPreference


# Get Network Adapter info
$Adapters = $null
if ($SQLInstance -eq 'localhost')
{
    try
    {
        $Adapters = (Get-CIMInstance Win32_NetworkAdapterConfiguration -ComputerName . -ErrorAction stop).where({$PSItem.IPEnabled})
    }
    catch
    {
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"| out-file $fullFileName -Encoding ascii -Append
    }
}
else
{
    try
    {
        $Adapters = (Get-CIMInstance Win32_NetworkAdapterConfiguration -ComputerName $WinServer -ErrorAction stop).where({$PSItem.IPEnabled})
    }
    catch
    {
        
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"
        Write-Output "Error Getting NetworkAdapter Info using Get-CimInstance"| out-file $fullFileName -Encoding ascii -Append
    }
}

if ($Adapters -ne $null)
{
    foreach ($Adapter in $Adapters)
    {
        # Get all Adapter Properties
        $AdapterSettings = [PSCustomObject]@{ 
        System = $Adapter.PSComputerName 
        Description = $Adapter.Description 
        IPAddress = $Adapter.IPAddress 
        SubnetMask = $Adapter.IPSubnet 
        DefaultGateway = $Adapter.DefaultIPGateway 
        DNSServers = $Adapter.DNSServerSearchOrder 
        DNSDomain = $Adapter.DNSDomain 
        DNSSuffix = $Adapter.DNSDomainSuffixSearchOrder 
        FullDNSREG = $Adapter.FullDNSRegistrationEnabled 
        WINSLMHOST = $Adapter.WINSEnableLMHostsLookup 
        WINSPRI = $Adapter.WINSPrimaryServer 
        WINSSEC = $Adapter.WINSSecondaryServer 
        DOMAINDNSREG = $Adapter.DomainDNSRegistrationEnabled 
        DNSEnabledWINS = $Adapter.DNSEnabledForWINSResolution 
        TCPNETBIOSOPTION = $Adapter.TcpipNetbiosOptions 
        IsDHCPEnabled = $Adapter.DHCPEnabled 
        AdapterName = $Adapter.Servicename
        MACAddress = $Adapter.MACAddress 
        } 

        $mystring ="Network Adapter[" +[array]::IndexOf($Adapters,$Adapter)+"]`r`n"
        $mystring+=  "Name: "+ $AdapterSettings.AdapterName+"`r`n"
        $index = 0
        foreach ( $Address in $AdapterSettings.IPAddress)
        {
            $mystring+= "Address["+[array]::IndexOf($AdapterSettings.IPAddress,$Address)+ "]: "+$Address+"`r`n"
        }

        foreach ( $subnet in $AdapterSettings.SubnetMask)
        {
            $mystring+= "Subnet["+[array]::IndexOf($AdapterSettings.SubnetMask,$subnet)+ "]: "+$Subnet+"`r`n"
        }
    
        $mystring+= "Gateway: {0}" -f $AdapterSettings.DefaultGateway+"`r`n"
        $mystring+="Description: {0}" -f $AdapterSettings.Description+"`r`n"
        $mystring+="DNS Name: {0}" -f $AdapterSettings.DNSServers
        $mystring+="`r`n" 
        $mystring | out-file $fullFileName -Encoding ascii -Append
    }

    # Section Footer
    "`r`nSQL Build reference: http://sqlserverbuilds.blogspot.com/ " | out-file $fullFileName -Encoding ascii -Append
    "`r`nSQL Build reference: http://sqlserverupdates.com/ " | out-file $fullFileName -Encoding ascii -Append
    "`r`nMore Detailed Diagnostic Queries here:`r`nhttp://www.sqlskills.com/blogs/glenn/sql-server-diagnostic-information-queries-for-september-2015" | out-file $fullFileName -Encoding ascii -Append

}

# Get Loaded DLLs
$mysql15 = "select * from sys.dm_os_loaded_modules order by description"


# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults15 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql15
}
else
{
	$sqlresults15 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql15 -User $myuser -Password $mypass

}

# HTML CSS
$head = "<style type='text/css'>"
$head+="
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
$head+="</style>"

$RunTime = Get-date

$myoutputfile4 = $FullFolderPath+"\02_Loaded_Dlls.html"
$myHtml1 = $sqlresults15 | select file_version, product_version, debug, patched, prerelease, private_build, special_build, language, company, description, name| `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Loaded DLLs</h2><h3>Ran on : $RunTime</h3>"
Convertto-Html -head $head -Body "$myHtml1" -Title "Loaded DLLs" | Set-Content -Path $myoutputfile4

# Get Trace Flags
$mysql16= "dbcc tracestatus();"

# connect correctly
if ($serverauth -eq "win")
{
	$sqlresults16 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql16
}
else
{
	$sqlresults16 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql16 -User $myuser -Password $mypass

}

if ($sqlresults16 -ne $null)
{
    Write-Output ("Trace Flags Found")
    $myoutputfile4 = $FullFolderPath+"\03_Trace_Flags.html"
    $myHtml1 = $sqlresults16 | select TraceFlag, Status, Global, Session | `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Trace Flags</h2><h3>Ran on : $RunTime</h3>"
    Convertto-Html -head $head -Body "$myHtml1" -Title "Trace Flags" | Set-Content -Path $myoutputfile4    
}
else
{
    Write-Output "No Trace Flags Set"
}


# Get Device Drivers
try
{
    $ddrivers = Get-WmiObject Win32_PnPSignedDriver -ComputerName $WinServer | where-object {$_.DeviceName -ne $null}| select DeviceName, FriendlyName, HardwareID, Manufacturer, DriverVersion| sort DeviceName
    $fullFileName = $fullfolderPath+"\04_Device_Drivers.html"
    $fullFileNameCSV = $fullfolderPath+"\04_Device_Drivers.csv"
    New-Item $fullFileName -type file -force  |Out-Null
    New-Item $fullFileNameCSV -type file -force  |Out-Null
    $ddrivers | ConvertTo-Html|out-file -filepath $fullFileName -Encoding Ascii -Append
    $ddrivers | ConvertTo-csv -NoTypeInformation|out-file -filepath $fullFileNameCSV -Encoding Ascii -Append
}
catch
{
    Write-Output('Could NOT get Device Drivers with WMI')
}



# Get Running Processes
try
{
    if ($WinServer -eq "localhost" -or $WinServer -eq ".")
    {
        $rprocesses = get-process
    }
    else
    {
        $rprocesses = get-process -ComputerName $WinServer
    }

    if ($rprocesses -ne  $null)
    {
        $myoutputfile4 = $FullFolderPath+"\05_Running_Processes.html"
        $myHtml1 = $rprocesses | select Name, Handles, VM, WS, PM, NPM | `
        ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Running Processes</h2><h3>Ran on : $RunTime</h3>"
        Convertto-Html -head $head -Body "$myHtml1" -Title "Running Processes"| Set-Content -Path $myoutputfile4
    }
}
catch
{
    Write-Output ("Running Processes: Could not connect")
}



# Get NT Services
try
{
    $Services = get-service -ComputerName $WinServer

    if ($Services -ne  $null)
    {
        $myoutputfile4 = $FullFolderPath+"\06_NT_Services.html"
        $myHtml1 = $Services | select Name, DisplayName, Status, StartType | `
        ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>NT Services</h2> <h3>Ran on : $RunTime</h3>"
        Convertto-Html -head $head -Body "$myHtml1" -Title "NT Services" | Set-Content -Path $myoutputfile4
    }
}
catch
{
    Write-Output ("NT Services: Could not connect")
}


# Get Server Configuration Settings
$mysql20 = 
"
SELECT *
  FROM sys.configurations
  ORDER BY [name]
;
"

# Connect correctly
if ($serverauth -eq "win")
{
    $sqlresults20 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql20
}
else
{
    $sqlresults20 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mysql20 -User $myuser -Password $mypass
}

# Convert dataset to html table
$myHtml1 = $sqlresults20 | select configuration_id, name, value, minimum, maximum, value_in_use, description, is_dynamic, is_advanced | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>Server Configurations</h2><h3>Ran on : $RunTime</h3>"
$myoutputfile20 = $FullFolderPath+"\01_Server_Configurations.html"
Convertto-Html -head $head -Body "$myHtml1" -Title "Server Configurations" | Set-Content -Path $myoutputfile20


# Check for Hybrid Memory Pool PMEM on NVDIMM DAX-formatted Drives
# https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/hybrid-buffer-pool?view=sql-server-ver15
# https://docs.microsoft.com/en-us/windows-server/storage/storage-spaces/deploy-pmem
if ($ver -ge 15)
{

    $mySQL25="SELECT * FROM sys.server_memory_optimized_hybrid_buffer_pool_configuration"
    $myoutputfile25 = $FullFolderPath+"\07_Hybrid_Memory_Pool.html"
    # Connect correctly
    if ($serverauth -eq "win")
    {
        $sqlresults25 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQL25
    }
    else
    {
        $sqlresults25 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQL25 -User $myuser -Password $mypass
    }

    $myHtml25 = $sqlresults25 | select is_configured, is_enabled| `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><h2>Hybrid Memory Pool (PMEM)</h2>"
    Convertto-Html -head $head -Body "$myHtml25" -Title "Hybrid Memory Pool" | Set-Content -Path $myoutputfile25

    
    $mySQL26="SELECT * FROM sys.configurations WHERE name = 'hybrid_buffer_pool'"
    $myoutputfile26 = $FullFolderPath+"\08_Hybrid_Memory_Pool_Configurations.html"
    # Connect correctly
    if ($serverauth -eq "win")
    {
        $sqlresults26 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQL26
    }
    else
    {
        $sqlresults26 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySQL26 -User $myuser -Password $mypass
    }

    $myHtml26 = $sqlresults26 | select is_configured, is_enabled| `
    ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><h2>Hybrid Memory Pool Configurations</h2>"
    Convertto-Html -head $head -Body "$myHtml26" -Title "Hybrid Memory Pool" | Set-Content -Path $myoutputfile26
    
}

# Return to Base
set-location $BaseFolder
