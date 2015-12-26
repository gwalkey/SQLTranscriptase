<#
.SYNOPSIS
    Gets the Windows SMB Shares on the target server
	
.DESCRIPTION
   Writes the SMB Shares out to the "01 - Server Shares" folder
   One file for all shares
   
.EXAMPLE
    Usage: 01_Server_Shares.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs
	HTML Files
	
.NOTES

	
.LINK

	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "01 - Server Shares"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -b black -f yellow "Usage: ./01_Server_Shares.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

# Some Self-explanatory text
$ShareArray = @()

# WMI connects to the Windows Server Name, not the SQL Server Named Instance
$WinServer = ($SQLInstance -split {$_ -eq "," -or $_ -eq "\"})[0]

# Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\01 - Server Shares\"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}


$old_ErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

try
{

    $ShareArray = Get-WmiObject -Computer $WinServer -class Win32_Share | select Name, Path, Description | Where-Object -filterscript {$_.Name -ne "ADMIN$" -and $_.Name -ne "IPC$"} | sort-object name
    #$ShareArray | Out-GridView
    if ($?)
    {
        Write-Output "Good WMI Connection"
    }
    else
    {   
        echo null > "$fullfolderpath\01 - Server Shares - WMI Could not connect.txt"
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
    echo null > "$fullfolderpath\01 - Server Shares - WMI Could not connect.txt"
       
    Set-Location $BaseFolder
    exit
}


# Reset default PS error handler - for WMI error trapping
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
$mySettings = $ShareArray
$mySettings | select Name, Path, Description  | ConvertTo-Html -PostContent "<h3>Ran on : $RunTime</h3>"  -PreContent "<h1>$SqlInstance</H1><H2>Server Shares</h2>" -CSSUri "HtmlReport.css"| Set-Content "$fullfolderPath\Shares_Overview.html"

# Loop Through Each Share, exporting NTFS and SMB permissions
Write-Output "Dumping NTFS/SMB Share Permissions..."


$PermPath = "$BaseFolder\$sqlinstance\01 - Server Shares\NTFS_Permissions\"
if(!(test-path -path $PermPath))
{
    mkdir $PermPath | Out-Null
}
$permpathfile = $PermPath + "NTFS_Permissions.txt"
"NTFS File Permissions for $Winserver shares`r" | out-file -FilePath $permpathfile -encoding ascii

$SMBPath = "$BaseFolder\$sqlinstance\01 - Server Shares\SMB_Permissions\"
if(!(test-path -path $SMBPath))
{
    mkdir $SMBPath | Out-Null
}
$SMBPathfile = $SMBPath + "SMB_Permissions.txt"
"SMB Share Permissions for $Winserver shares`r" | out-file -FilePath $SMBPathfile -encoding ascii

Function Get-NtfsRights($name,$path,$comp)
{
	$path = [regex]::Escape($path)
	$share = "\\$comp\$name"

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

	$wmi = gwmi Win32_LogicalFileSecuritySetting -filter "path='$path'" -ComputerName $comp
	$wmi.GetSecurityDescriptor().Descriptor.DACL | where {$_.AccessMask -as [Security.AccessControl.FileSystemRights]} |select `
				@{name="Principal";Expression={"{0}\{1}" -f $_.Trustee.Domain,$_.Trustee.name}},
				@{name="Rights";Expression={[Security.AccessControl.FileSystemRights] $_.AccessMask }},
				@{name="AceFlags";Expression={[Security.AccessControl.AceFlags] $_.AceFlags }},
				@{name="AceType";Expression={[Security.AccessControl.AceType] $_.AceType }},
				@{name="ShareName";Expression={$share}}

    # Reset default PS error handler - for WMI error trapping
    $ErrorActionPreference = $old_ErrorActionPreference 
}

foreach($Share in $ShareArray)
{
    # Skip certain shares
    if ($Share.name -eq "print$") {continue}
    if ($Share.name -eq "FILESTREAM") {continue}
    if ($Share.name -eq "IPC$") {continue}
    if ($Share.name -eq "ADMIN$") {continue}
    
    # Skip shares with spaces in the path  - can you even connect to these?
    # $Share.path

    if ($Share.path.Contains(' '))
     {
        Write-Output ("--> Could not script out Share [{0}], with Path [{1}]" -f $share.name, $share.path)
        continue
     }

    # Get Security Descriptors on NTFS for the share
    $acl = Get-NtfsRights $Share.Name $Share.Path $WinServer

    # Enum
    foreach($accessRule in $acl)
    {
        Write-Output ("Share: {0}, Path: {1}, Identity: {2}, Rights: {3}" -f $accessRule.ShareName, $Share.path, $accessRule.Principal, $accessRule.Rights)
        Write-Output ("Share: {0}, Path: {1}, Identity: {2}, Rights: {3}" -f $accessRule.ShareName, $Share.path, $accessRule.Principal, $accessRule.Rights) | out-file -FilePath $permpathfile -append -encoding ascii
    }

    Write-Output ("`r`n") | out-file -FilePath $permpathfile -append -encoding ascii
   
    # Get Share SMB Perms
    $ShareName = $Share.Name
    $SMBShare = Get-WmiObject win32_LogicalShareSecuritySetting -Filter "name='$ShareName'" -ComputerName $WinServer
    if($SMBShare)
    {
        $obj = @()
        $ACLS = $SMBShare.GetSecurityDescriptor().Descriptor.DACL
        foreach($ACL in $ACLS)
        {
            $User = $ACL.Trustee.Name
            if(!($user)){$user = $ACL.Trustee.SID}
            $Domain = $ACL.Trustee.Domain
            switch($ACL.AccessMask)
            {
                2032127 {$Perm = "Full Control"}
                1245631 {$Perm = "Change"}
                1179817 {$Perm = "Read"}
            }

            Write-Output ("Share: {0}, Domain: {1}, User: {2}, Permission: {3}" -f $ShareName, $Domain, $User, $Perm)
            Write-Output ("Share: {0}, Domain: {1}, User: {2}, Permission: {3}" -f $ShareName, $Domain, $User, $Perm) | out-file -FilePath $SMBPathfile -append -encoding ascii            
            
        }
    }
}

set-location "$BaseFolder"


