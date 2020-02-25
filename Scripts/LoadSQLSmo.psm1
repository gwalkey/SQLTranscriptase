<#
.SYNOPSIS
    Loads the latest SQL Server SMO .NET assembly installed on your machine
	
.DESCRIPTION
    Loads the latest SQL Server SMO .NET assembly installed on your machine
	
.EXAMPLE
    To call from other Scripts use:
    Import-Module LoadSQLSmo
    LoadSQLSMO
	
.Inputs

.Outputs
	
.NOTES
    Loading SQL SMO Assemblies - let me count the ways

    http://www.madwithpowershell.com/2013/10/add-type-vs-reflectionassembly-in.html

    1)     
    Original PShell 1/2 method: 
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

    2) Quick Way - but what version do you load?
    Add-Type -AssemblyName “Microsoft.SqlServer.Smo” 

    3) "Recommended Way"
    Add-Type –AssemblyName “Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”
    
    4) Hard-Coded filepath
    Add-Type -Path 'C:\Program Files\Microsoft SQL Server\120\SDK\Assemblies\Microsoft.SqlServer.Smo.dll'

    5) Hard Coded GAC path
    Add-Type -Path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\12.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

    List all Loaded Assemblies:
    [System.AppDomain]::CurrentDomain.GetAssemblies() | 
        Where-Object Location |
        Sort-Object -property Location |
        Out-GridView
    
    Latest SMO Library Changed in 2019 to use Nuget - which is independent of SQL Server Major Version releases
    https://www.nuget.org/packages/Microsoft.SqlServer.SqlManagementObjects
    Find-Package -Name "Microsoft.SqlServer.SqlManagementObjects" -AllVersions -Source "https://www.nuget.org/api/v2"
    get-package | sort version | ogv

    All NuGet Verbs
    https://docs.microsoft.com/en-us/nuget/reference/powershell-reference

	
.LINK
	
#>

function LoadSQLSMO(){

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'


    # Try NuGet Package Version
    try
    {
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Smo.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.SmoExtended.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.XEvent.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.XEventEnum.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.Sdk.Sfc.dll" -ErrorAction Stop
        Write-Output "Using SMO Library [vNext] (150.18208.0)"
        return
    }
    catch
    {
    }


    # 2019
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v15 (2019)"
        return
    }
    catch
    {
    }
	
    # 2017
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v14 (2017)"
        return
    }
    catch
    {
    }

    # 2016
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v13 (2016)"
        return
    }
    catch
    {
    }

    # 2014
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v12 (2014)"
        return
    }
    catch
    {
    }

    # 2012
    try 
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v11 (2012)"
        return
    }
    catch
    {
    }

    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library 10 (2008)"
    }
    catch
    {
    }

    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        #Write-Output "Using SMO Library 9 (2005)"
    }
    catch
    {
    }

    Write-output "No 2005+ SMO Libraries found on your Machine. Please load the latest version of SMO and try again"
    return
                   
}

export-modulemember -function LoadSQLSMO
