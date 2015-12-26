<#
.SYNOPSIS
    Gets the Windows Disk Volumes on the target server
	
.DESCRIPTION
   Writes the Disk Volumes out to the "01 - Server Storage" folder
   One file for all volumes
   This is to know what drive and mount-points the server has
   
.EXAMPLE
    01_Server_Storage.ps1 localhost
	
.EXAMPLE
    01_Server_Storage.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML File
	
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

Write-Host  -f Yellow -b Black "01 - Server Storage"


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./01_Server_Storage.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

# Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Storage\"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

# Split out servername only from named instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

# Credit: https://sqlscope.wordpress.com/2012/05/05/
$VolumeTotalGB = @{Name="VolumeTotalGB";Expression={[Math]::Round(($_.Capacity/1GB),2)}}
$VolumeUsedGB =  @{Name="VolumeUsedGB";Expression={[Math]::Round((($_.Capacity - $_.FreeSpace)/1GB),2)}}
$VolumeFreeGB =  @{Name="VolumeFreeGB";Expression={[Math]::Round(($_.FreeSpace/1GB),2)}}

# Let WMI errors be trapped
$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

try
{
    #$VolumeArray = Get-WmiObject -Computer $WinServer Win32_Volume | Where-Object {$_.FileSystem -eq "NTFS"} | sort-object name 
	$VolumeArray = Get-WmiObject -Computer $WinServer Win32_Volume | sort-object name 
    if ($?)
    {
        Write-Output "Good WMI Connection"
    }
    else
    {
        $fullfolderpath = "$BaseFolder\$SQLInstance\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        echo null > "$fullfolderpath\01 - Server Storage - WMI Could not connect.txt"
        
        Set-Location $BaseFolder
        exit
  
    }
}
catch
{
    $fullfolderpath = "$BaseFolder\$SQLInstance\"
    if(!(test-path -path $fullfolderPath))
    {
         mkdir $fullfolderPath | Out-Null
    }
    echo null > "$fullfolderpath\01 - Server Storage - WMI Could not connect.txt"
        
    Set-Location $BaseFolder
    exit
}

# Reset default PS error handler - WMI error trapping
$ErrorActionPreference = $old_ErrorActionPreference 


# Create some CSS for help in column formatting
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

$myCSS | out-file "$fullfolderPath\HTMLReport.css" -Encoding ascii

# Export It
$RunTime = Get-date
$mySettings = $VolumeArray
$mySettings | select Name, Label, FileSystem, DriveType, $VolumeTotalGB, $VolumeUsedGB, $VolumeFreeGB, BootVolume, DriveLetter, BlockSize  | ConvertTo-Html -PostContent "<h3>Ran on : $RunTime</h3>"  -PreContent "<h1>$SqlInstance</H1><H2>Server Storage Volumes</h2>" -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\HtmlReport.html"


set-location $BaseFolder
