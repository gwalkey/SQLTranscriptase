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
Write-Host  -f Yellow -b Black "11 - SSRS Objects"
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

function Get-SSRSVersion
{
    [CmdletBinding()]
    Param(
        [string]$SQLInstance="localhost"
    )

    # Get SSRS (NOT underlying SQL) Version
    $ssrsProxy = Invoke-WebRequest -Uri "http://$SQLInstance/reportserver" -UseDefaultCredential
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
        # Try Powerbi Repotrting Server
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
            $version = 'unknown'
        }
    }

    Write-Output($version)
}

$SSRSVersion = Get-SSRSVersion $SQLInstance
Write-Output ("SSRS Version: {0}" -f $SSRSVersion)


# Create some CSS for help in column formatting during HTML exports
$myCSS = 
"
<style type='text/css'>
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
</style>
"


set-location $BaseFolder

# Create output folder
$folderPath = "$BaseFolder\$sqlinstance"
if(!(test-path -path $folderPath))
{
    mkdir $folderPath | Out-Null
}

# Get RDL Reports and or PowerBI PBIX
if ($SSRSFamily -eq 'PowerBI')
{
    $sqlCMDRDL = 
    "
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
		    'BINARYXML' AS 'contentType',
		    CONVERT(varbinary(max),Content) AS Content
	    FROM ReportServer.dbo.Catalog
	    WHERE Type IN (2,5,7,8)

	    UNION

	    SELECT
		    c.ItemID,
		    c.ParentID,
		    c.[Name],
		    c.[Type],
		    'Power BI Report' as 'TypeDescription',
		    e.ContentType,
		    CONVERT(varbinary(max),e.Content) AS Content
	    FROM 
		    ReportServer.dbo.Catalog C
	    INNER JOIN 
		    reportserver.dbo.CatalogItemExtendedContent E
	    ON
		    c.ItemID = e.ItemId
	    WHERE 
            c.Type IN (13) AND e.ContentType='CatalogItem'
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
		    ContentType,
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
	    ContentType,
        Content, --varbinary
        CASE
		    WHEN ContentType ='BINARYXML' THEN CONVERT(varchar(max),Content)
		    WHEN ContentType IN ('CatalogItem','DataModel','PowerBIReportDefinition') THEN null
	     END AS ContentVarchar, --varchar
        CASE 
		    WHEN ContentType ='BINARYXML' THEN CONVERT(xml,Content) 
		    WHEN ContentType IN ('CatalogItem','DataModel','PowerBIReportDefinition') THEN null
	    END AS ContentXML --xml
    FROM ItemContentNoBOM
    order by 2
    "
}
else
{
    $sqlCMDRDL = 
    "
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
		    'BINARYXML' AS 'contentType',
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
		    ContentType,
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
	    ContentType,
        Content, --varbinary
        CASE
		    WHEN ContentType ='BINARYXML' THEN CONVERT(varchar(max),Content)
		    WHEN ContentType IN ('CatalogItem','DataModel','PowerBIReportDefinition') THEN null
	     END AS ContentVarchar, --varchar
        CASE 
		    WHEN ContentType ='BINARYXML' THEN CONVERT(xml,Content) 
		    WHEN ContentType IN ('CatalogItem','DataModel','PowerBIReportDefinition') THEN null
	    END AS ContentXML --xml
    FROM ItemContentNoBOM
    order by 2
    "
}

$sqlToplevelfolders = "
--- Root
SELECT 
	[ItemId],
	[ParentID],
	'/' AS 'Path'
FROM 
	[ReportServer].[dbo].[Catalog]
where 
	Parentid is null and [Type] = 1

UNION

SELECT 
	[ItemId],
	[ParentID],
	[Path]
FROM 
	[ReportServer].[dbo].[Catalog]
where 
	Parentid is not null and [Type] = 1 AND [Name]<>'System Resources'
ORDER BY [Path]
"



# initialize arrays
$Packages = [System.Collections.ArrayList]@()
$toplevelfolders = [System.Collections.ArrayList]@()
$skeds = [System.Collections.ArrayList]@()

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


    # Get Packages
    try
    {
        $Packages = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMDRDL -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }


    # Get Top-Level Folders
    try
    {
        $toplevelfolders = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlToplevelfolders -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
    
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


    # Get Packages
    try
    {
        $Packages = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMDRDL -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }

    # Get Top-Level Folders
    try
    {
        $toplevelfolders = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlToplevelfolders -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }


}

# Create output folders
set-location $BaseFolder
$fullfolderPath = "$BaseFolder\$sqlinstance\11 - SSRS"
$fullfolderPathRDL = "$BaseFolder\$sqlinstance\11 - SSRS\Reports"
$fullfolderPathSUB = "$BaseFolder\$sqlinstance\11 - SSRS\Subscriptions"
$fullfolderPathKey = "$BaseFolder\$sqlinstance\11 - SSRS\EncryptionKey"
$fullfolderPathFolders = "$BaseFolder\$sqlinstance\11 - SSRS\Folders"

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

if(!(test-path -path $fullfolderPathFolders))
{
    mkdir $fullfolderPathFolders | Out-Null
}
	

# -----------------------------------------
# 1) Get SSRS Version and Supported Interfaces
# -----------------------------------------
Write-Output ("SSRS Version: {0}" -f $SSRSVersion) | out-file -Force -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
$SOAPAPIVersion=''
$RESTAPIVersion=''

if ($SSRSVersion -ne 'unknown')
{

    # 2005
    if ($SSRSVersion -like '9.0*')
    {
        "Supports SOAP Interface 2005"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2005.asmx"
        $RESTAPIVersion=$null
    }

    # 2008
    if ($SSRSVersion -like '10.0*')
    {
        "Supports SOAP Interface 2005"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2005.asmx"
        $RESTAPIVersion=$null
    }

    # 2008 R2
    if ($SSRSVersion -like '10.5*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion=$null
    }

    # 2012
    if ($SSRSVersion -like '11.0*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion=$null
    }

    # 2014
    if ($SSRSVersion -like '12.0*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion=$null
    }

    # 2016
    if ($SSRSVersion -like '13.0*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        "Supports REST Interface v1.0"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion="http://$SQLInstance/reports/api/v1.0"
    }

    # 2017
    if ($SSRSVersion -like '14.0*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        "Supports REST Interface v2.0"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion="http://$SQLInstance/reports/api/v2.0"
    }
    
    # PowerBI
    if ($SSRSVersion -like '15.0*')
    {
        "Supports SOAP Interface 2010"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        "Supports REST Interface v2.0"| out-file -append -encoding ascii -FilePath "$fullfolderPath\SSRSVersion.txt"
        $SOAPAPIVersion="http://$SQLInstance/ReportServer/ReportService2010.asmx"
        $RESTAPIVersion="http://$SQLInstance/reports/api/v2.0"
    }
}


# --------
# 2) RDL
# --------
Write-Output "Writing out Report RDL.."

# Create Output Folder Structure to mirror the SSRS ReportServer Catalog and dump the RDL into the respective folder tree
foreach ($tlfolder in $toplevelfolders)
{
    # Create Folder Structure, Fixup forward slashes
    $myNewStruct = $fullfolderPathRDL+$tlfolder.Path
    $myNewStruct = $myNewStruct.replace('/','\')
    if(!(test-path -path $myNewStruct))
    {
        mkdir $myNewStruct | Out-Null
    }

    # Only Script out the Reports in this Folder (Report ParentID matches Folder ItemID
    $myParentID = $tlfolder.ItemID
    Foreach ($pkg in $Packages)
    {
        if ($pkg.ParentID -eq $myParentID)
        {

            # Get the Report ID, Name
            $myItemID = $pkg.ItemID
            $pkgName = $Pkg.name
            Write-Output('Package: {0}' -f $pkgName)

            # Report RDL
            if ($pkg.Type -eq 2)
            {    
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.rdl"
            }

            # Shared Data Source
            if ($pkg.Type -eq 5)
            {    
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.shdsrc.txt"
            }

            # Shared Dataset
            if ($pkg.Type -eq 8)
            {
                $pkg.ContentXML | Out-File -Force -encoding ascii -FilePath "$myNewStruct\$pkgName.shdset.txt"
            }

            # Power BI Report
            if ($pkg.Type -eq 13)
            {
                [io.file]::WriteAllBytes("$myNewStruct\$pkgName.pbix",$pkg.Content)
                #$pkg.Content | Set-Content "$myNewStruct\$pkgName.pbix" -Encoding Byte                 
            }


            Write-Output("Item: [{0}], Type: [{1}]" -f $pkg.name, $pkg.Type)
            # Other Types include
            # 3 - File/Resource
            # 4 - Linked Report
            # 6 - Model
            # 7 - 
            # 9 - 

            

        } # Parent
    } # Items in this folder


}


# ----------------------------
# 3) SSRS Configuration Files
# ----------------------------
Write-Output "Writing SSRS Settings to file..."
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# 2008?
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

# 2012?
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

# 2014?
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

# 2016?
if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_MSSQLSERVER\v13\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 13
            Write-Output "Found SSRS v13 (2016)"
        }
        else
        {
            #Write-Output "NOT v13"
        }
    }
    catch
    {
        #Write-Output "NOT v13"
    }
}

# 2017
if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\V14" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 14
            Write-Output "Found SSRS v14 (2017)"
        }
        else
        {
            #Write-Output "NOT v13"
        }
    }
    catch
    {
        #Write-Output "NOT v13"
    }
}

# Power BI?
if ($wmi1 -eq 0)
{
    try 
    {
        get-wmiobject -namespace "root\Microsoft\SQlServer\ReportServer\RS_PBIRS\v15\Admin" -class MSREportServer_configurationSetting -computername $SQLInstance | out-file -FilePath "$fullfolderPath\Server_Config_Settings.txt" -encoding ascii
        if ($?)
        {
            $wmi1 = 15
            Write-Output "Found SSRS v15 (Power BI)"
        }
        else
        {
            #Write-Output "NOT v15"
        }
    }
    catch
    {
        #Write-Output "NOT v15"
    }
}

# Reset default PS error handler - for WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 

# ------------------------------
# 4) RSReportServer.config File
# ------------------------------
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

# 2016
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS13.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server\MSRS13.MSSQLSERVER\Reporting Services\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# 2017
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft SQL Server Reporting Services\SSRS\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft SQL Server Reporting Services\SSRS\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Power BI
$copysrc = "\\$sqlinstance\c$\Program Files\Microsoft Power BI Report Server\PBIRS\ReportServer\RSreportserver.config"
copy-item "\\$sqlinstance\c$\Program Files\Microsoft Power BI Report Server\PBIRS\ReportServer\RSreportserver.config" $fullfolderPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue


# ---------------------------
# 5) Database Encryption Key
# ---------------------------
Write-Output "Backup SSRS Encryption Key..."
Write-Output ("WMI found SSRS version {0}" -f $wmi1)

# 2008 no WMI
if ($wmi1 -eq 10)
{
    Write-Output "SSRS 2008 - cant access Encryption key from WMI. Please use rskeymgmt.exe on server to export the key"
    New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
    Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
}

# We can use WMI against 2012+ SSRS Servers
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

# 2016
if ($wmi1 -eq 13)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\microsoft\sqlserver\reportserver\rs_mssqlserver\v13\admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
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
            Write-Output "Error Connecting to WMI for config file (v13)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
        Write-Output "Error Connecting to WMI for config file (v13) 2"
    }
}

# 2017
if ($wmi1 -eq 14)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\V14\Admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
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
            Write-Output "Error Connecting to WMI for config file (v14)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
        Write-Output "Error Connecting to WMI for config file (v14) 2"
    }
}

# Power BI Report Server
if ($wmi1 -eq 15)
{
    try
    {
        $serverClass = get-wmiobject -namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\V14\Admin" -class "MSReportServer_ConfigurationSetting" -computername $SQLInstance
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
            Write-Output "Error Connecting to WMI for config file (v13)"
        }
    }
    catch
    {
        New-Item "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -type file -force  |Out-Null
        Add-Content -Value "Use the rskeymgmt.exe app on the SSRS server to export the encryption key" -Path "$fullfolderPathKey\SSRS_Encryption_Key_not_exported.txt" -Encoding Ascii
        Write-Output "Error Connecting to WMI for config file (v13) 2"
    }
}

# Reset default PS error handler - cause WMI error trapping sucks
$ErrorActionPreference = $old_ErrorActionPreference 

# ---------------------
# 6) Timed Subscriptions
# ---------------------
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

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $Skeds = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $myRDLSked -ErrorAction Stop
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
        $Skeds = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $myRDLSked -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}


$RunTime = Get-date
Write-Output "Visual Timed Subscriptions..."
$HTMLFileName = "$fullfolderPathSUB\Visual_Subscription_Schedule.html"

$Skeds | select Folder, Report, State, RecurrenceType, RunTime, Weeks_Interval, Minutes_Interval, `
Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec, `
Week_of_Month, Sun, Mon, Tue, Wed, Thu, Fri, Sat, RunHour,  `
00Z, 01Z, 02Z, 03Z, 04Z, 05Z, 06Z, 07Z, 08Z, 09Z, 10Z, 11Z, 12Z, 13Z, 14Z, 15Z, 16Z, 17Z, 18Z, 19Z, 20Z, 21Z, 22Z, 23Z `
| ConvertTo-Html -Head $myCSS -PostContent "<h3>Ran on : $RunTime</h3>" -CSSUri "HtmlReport.css"| Set-Content $HTMLFileName

# Script out the Create Subscription Commands
Write-Output "Timed Subscriptions..."

# Older SSRS version dont have the ReportZone Column
if ($myver -ilike '9.0*' -or $myver -ilike '10.0*' -or $myver -ilike '10.5*')
{
    $mySubs = 
    "
    USE [ReportServer];

    select 
	    'exec CreateSubscription @id='+char(39)+convert(varchar(40),S.[SubscriptionID])+char(39)+', '+
	    '@Locale=N'+char(39)+S.[Locale]+char(39)+', '+
	    '@Report_Name=N'+char(39)+R.Name+char(39)+', '+
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
}
else
{
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
}

# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $SubCommands = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySubs -ErrorAction Stop
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
        $SubCommands = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $mySubs -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
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
# 7) Folder Permissions
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

Write-Output "Folder Permissions..."
$sqlSecurity = "
Use ReportServer;

select 
    E.Path, 
    E.Name, 
    C.UserName, 
    D.RoleName
from 
    dbo.PolicyUserRole A
inner join 
    dbo.Policies B 
ON 
    A.PolicyID = B.PolicyID
inner join 
    dbo.Users C 
on 
    A.UserID = C.UserID
inner join 
    dbo.Roles D 
on 
    A.RoleID = D.RoleID
inner join 
    dbo.Catalog E 
on 
    A.PolicyID = E.PolicyID
Where
    E.[Name] not in ('System Resources')
order by 
    1
"

# Get Permissions
if ($serverauth -eq "win")
{
    try
    {
        $sqlPermissions = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlSecurity -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL Getting Folder Permissions: {0}" -f $error[0])
    }
}
else
{
try
    {
        $sqlPermissions = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlSecurity -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Write-Output("Error Connecting to SQL Getting Folder Permissions: {0}" -f $error[0])
    }
}

$sqlPermissions | select Path, Name, UserName, RoleName | ConvertTo-Html -Head $myCSS -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content "$fullfolderPathFolders\PermissionsReport.html"
$sqlPermissions | select Path, Name, UserName, RoleName | ConvertTo-json -Depth 4 | out-file -FilePath "$fullfolderPathFolders\FolderTreePermissions.json" -Force -Encoding ascii


# 9) Folder Tree Structure - Serialize
Write-Output "Folder Tree Structure..."

# Can we use the REST API?
if ($SSRSVersion -like '13.0*' -or $SSRSVersion -like '14.0*' -or $SSRSVersion -like '15.0*')
{
    switch($SSRSVersion.Substring(0,2))
    {
        13 {$RESTAPIVersion = "v1.0"}
        14 {$RESTAPIVersion = "v2.0"}
        15 {$RESTAPIVersion = "v2.0"}
    }

    $URI = "http://$SQLInstance/reports/api/$RESTAPIVersion"
    $response  = Invoke-RestMethod "$URI/CatalogItems" -Method get -UseDefaultCredentials
    $FolderTree = $response.value | Where-Object {$_.Type -eq 'Folder'} | select path
    $FolderTree | convertto-json -Depth 4 | out-file -FilePath "$fullfolderPathFolders\FolderTreeStructure.json" -Force -Encoding ascii
    # Read Back in
    # $NewFolderTree = get-content -Path "$fullfolderPath\FolderTree.json" | ConvertFrom-Json
}

# Use SOAP on older verisons
if ($SSRSVersion -like '9.0*' -or $SSRSVersion -like '10.0*' -or $SSRSVersion -like '10.5*' -or $SSRSVersion -like '11.0*' -or $SSRSVersion -like '12.0*')
{
    if ($SSRSVersion -like '9.0*')
    {
        $ReportServerUri  = "http://$SQLInstance/ReportServer/ReportService2005.asmx"
    }
    else
    {
        $ReportServerUri  = "http://$SQLInstance/ReportServer/ReportService2010.asmx"
    }

    # Get SOAP Proxy
    $rs2010 = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential;
    $type = $rs2010.GetType().Namespace    
    $CatalogItemDataType = ($type + '.catalogItems')    
    $CatalogItems= $rs2010.ListChildren("/",$true)
    $FolderTree = $CatalogItems | Where-Object {$_.TypeName -eq 'Folder'} | select Path
    $FolderTree | convertto-json -Depth 4 | out-file -FilePath "$fullfolderPathFolders\FolderTree.json" -Force -Encoding ascii
    # Read Back in
    # $NewFolderTree = get-content -Path "$fullfolderPath\FolderTree.json" | ConvertFrom-Json
}

# 10) Subscriptions as JSON Document Collection
Write-Output "Serialize Subscriptions as a JSON Document Collection..."

# Can we use the REST API?
if ($SSRSVersion -like '13.0*' -or $SSRSVersion -like '14.0*' -or $SSRSVersion -like '15.0*')
{
    switch($SSRSVersion.Substring(0,2))
    {
        13 {$RESTAPIVersion = "v1.0"}
        14 {$RESTAPIVersion = "v2.0"}
        15 {$RESTAPIVersion = "v2.0"}
    }

    $URI = "http://$SQLInstance/reports/api/$RESTAPIVersion"
    $response  = Invoke-RestMethod "$URI/Subscriptions" -Method get -UseDefaultCredentials
    $response.value | ConvertTo-Json -Depth 4 | out-file -FilePath "$fullfolderPathSUB\Subscriptions.json" -Force -Encoding ascii    
}

# Use SOAP on older versions
if ($SSRSVersion -like '9.0*' -or $SSRSVersion -like '10.0*' -or $SSRSVersion -like '10.5*' -or $SSRSVersion -like '11.0*' -or $SSRSVersion -like '12.0*' -or  $SSRSVersion -like '14.0*')
{
    if ($SSRSVersion -like '9.0*')
    {
        $ReportServerUri  = "http://$SQLInstance/ReportServer/ReportService2005.asmx"
    }
    else
    {
        $ReportServerUri  = "http://$SQLInstance/ReportServer/ReportService2010.asmx"
    }

    # Get SOAP Proxy
    $rs2010 = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential;
    $type = $rs2010.GetType().Namespace
    $CatalogItems= $rs2010.ListSubscriptions("/")
    $CatalogItems | ConvertTo-Json -Depth 4 | out-file -FilePath "$fullfolderPathSUB\Subscriptions2.json" -Force -Encoding ascii 
    
}


# Return to Base
set-location $BaseFolder

