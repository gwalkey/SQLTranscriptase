<#
.SYNOPSIS
    Installs the SMO and DacFX Library DLLs from NuGet Packages
	
.DESCRIPTION
    Installs the SMO and DacFX Library DLLs from NuGet Packages
   
.EXAMPLE


.Inputs
    Run Elevated

.Outputs
    Packages installed in c:\Program Files\PackageManagement
	
.NOTES


.LINK



	
#>
#Requires -RunAsAdministrator

Register-PackageSource -Name Nuget -Location "http://www.nuget.org/api/v2" –ProviderName Nuget -Trusted

Install-Package Microsoft.SqlServer.DacFx.x64 -source 'Nuget'
Install-Package Microsoft.SqlServer.SqlManagementObjects -skipdependencies -source 'Nuget'