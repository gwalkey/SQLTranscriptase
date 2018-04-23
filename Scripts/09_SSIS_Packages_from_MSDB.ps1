<#
.SYNOPSIS
    Gets the SQL Server Integration Services packages stored in MSDB on the target server
	
.DESCRIPTION
   Writes the SSIS Packages out to the "09 - SSIS_MSDB" folder
   
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 localhost
	
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
	Might have to run this Elevated (As Administrator) on Windows 8+
	
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
Write-Host  -f Yellow -b Black "09 - SSIS Packages from MSDB"
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


# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\09 - SSIS_MSDB"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }


# SSIS 2005
if ($myver -like "9.0*")
{

    Write-Output "SSIS version is 2005"

    $Packages = @()
    $sqlCMD2 = "
    with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysdtspackagefolders90 PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysdtspackagefolders90 CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysdtspackages90 P on P.folderid = F.folderid
        WHERE F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

    # Run Query
    if ($serverauth -eq "win")
    {
        try
        {
            $Packages = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
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
            $Packages = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }

    #Save
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
    }
}

# SSIS 2008 +
else
{
    Write-Output "SSIS is 2008+"
	
    $Packages = @()
    $sqlCMD2 = "
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysssispackagefolders PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysssispackagefolders CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysssispackages P on P.folderid = F.folderid
        WHERE    F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

    # Run Query
    if ($serverauth -eq "win")
    {
        try
        {
            $Packages = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -ErrorAction Stop
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
            $Packages = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }


    # Export Packages to DTSX Files
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"

        $Pkg.packagename
    }


    Write-Output ("{0} SSIS MSDB Packages Exported" -f @($packages).count)
}

# Return To Base
set-location $BaseFolder
