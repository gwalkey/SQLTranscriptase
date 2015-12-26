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

    2)
    Add-Type -AssemblyName “Microsoft.SqlServer.Smo” 

    3) "Recommended Way"
    Add-Type –AssemblyName “Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91”
    
    4) Hard-Coded filepath
    Add-Type -Path 'C:\Program Files\Microsoft SQL Server\120\SDK\Assemblies\Microsoft.SqlServer.Smo.dll'

    5) - Hard Coded GAC path
    Add-Type -Path “C:\Windows\assembly\GAC_MSIL\Microsoft.SqlServer.Smo\12.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.Smo.dll”

    List all Loaded Assemblies:
    [appdomain]::currentdomain.getassemblies()
	
.LINK
	
#>

function LoadSQLSMO(){

    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        Write-Output "Using SMO Library v13 (2016)"
    }

    catch
    {    
        try
        {
            Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
            Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
            Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
            Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
            Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
            Write-Output "Using SMO Library v12 (2014)"
        }
        catch
        {    
            try 
            {
                Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                Write-Output "Using SMO Library v11 (2012)"
            }
            catch
            {
                try
                {
                    Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                    Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"                    
                    Write-Output "Using SMO Library 10 (2008)"
                }
                catch
                {
                    try
                    {
                        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
                        Write-Output "Using SMO Library 9 (2005)"
                    }
                    catch
                    {
                        Write-output "No 2005+ SMO Libraries found on your Machine. Please load the latest version of SMO and try again"
                        return
                   
                    }
                }
            }
        }

    }
}

export-modulemember -function LoadSQLSMO
