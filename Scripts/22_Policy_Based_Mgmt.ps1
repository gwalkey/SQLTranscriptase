<#
.SYNOPSIS
   Gets the Policy Based Mgmt Objects on the target server
	
.DESCRIPTION
   Writes the Policies and Facets out to the "22 - PBM" folder
      
.EXAMPLE
    22_Policy_Based_Mgmt.ps1 localhost
	
.EXAMPLE
    22_Policy_Based_Mgmt.ps1 server01 sa password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.dmf.aspx
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.facets.aspx
	
.LINK
	https://github.com/gwalkey
	
#>

[CmdletBinding()]
Param(
  [string]$SQLInstance="localhost",
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
Write-Host  -f Yellow -b Black "22 - Policy Based Mgmt Objects"
Write-Output "Server $SQLInstance"

# Load DMF Assemblies
$dmfver = $null;

try 
{
  # 2017
  $dmfver = 14
  Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
}
catch 
{
    try 
    {
        # 2016
        $dmfver = 13
	    Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	    Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
    }
    catch 
    {
	    try 
        {
	        # 2014
            $dmfver = 12
	        Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	        Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	    }
	    catch 
        {
  	        try 
            {
		        # 2012
                $dmfver = 11
		        Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		        Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
	        }
	        catch 
            {
        	    try 
                {
		            # 2008
                    $dmfver = 10
		            Add-Type -AssemblyName 'Microsoft.SqlServer.Dmf, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		            Add-Type -AssemblyName 'Microsoft.SqlServer.Management.Sdk.Sfc, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
		        }
		        catch 
                {
		            Write-Warning 'SMO components not installed'
		            throw('SMO components not installed')
		        }
	        }
	    }
    }
}


If (!($dmfver))
{
    Write-Output "'Microsoft.SqlServer.Dmf.dll' or 'Microsoft.SqlServer.Management.Sdk.Sfc.dll' not found, exiting"
    exit
}


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


# New UP SFC Object
if ($serverauth -eq "win")
{
    $conn = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection("server=$SQLInstance;Trusted_Connection=true")
    $PolicyStore = New-Object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)
}
else
{
    $conn = New-Object Microsoft.SqlServer.Management.Sdk.Sfc.SqlStoreConnection("server='$SQLInstance';Trusted_Connection=false; User Id=$myuser; Password=$mypass")
    $PolicyStore = New-Object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)
}


# Prep Output Folders
Write-Output "$SQLInstance - PBM"
$Output_path  = "$BaseFolder\$SQLInstance\22 - PBM\"
if(!(test-path -path $Output_path))
{
    mkdir $Output_path | Out-Null	
}

# Policies
$POutput_path  = "$BaseFolder\$SQLInstance\22 - PBM\Policies\"
if(!(test-path -path $POutput_path))
{
    mkdir $POutput_path | Out-Null	
}

# Conditions
$COutput_path  = "$BaseFolder\$SQLInstance\22 - PBM\Conditions\"
if(!(test-path -path $COutput_path))
{
    mkdir $COutput_path | Out-Null
}

Write-Output "Writing Out..."

# Script Out
if ($PolicyStore -ne $null)
{
    # New UP Policy Store Object
    Write-Output "Exporting PBM Policies and Conditions..."
    $PolicyStore = New-Object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)    

    # Script out Policies
    $Policies = $PolicyStore.Policies | Where-Object { -not $_.IsSystemObject }
    foreach($policy in $Policies)
    {
        $myPName = $Policy.Name
        $myfixedName = $myPName.replace('\','_')
        $myfixedName = $myfixedName.replace('!','_')
        $myfixedName = $myfixedName.replace('/','_')
        $myfixedName = $myfixedName.replace('%','_')
        $Outfilename = $POutput_path+"$myfixedName.xml"

        Write-Output("Policy: {0}" -f $myfixedName)
        $xmlWriter = [System.Xml.XmlWriter]::Create($Outfilename)
        $policy.Serialize($xmlWriter)
        $xmlWriter.Close()
    }


    # Script out Conditions
    $myConditions = $PolicyStore.Conditions | Where-Object { -not $_.IsSystemObject }    
    foreach($Condition in $myConditions)
    {
        $myCName = $Condition.Name
        $myfixedName = $myCName.replace('\','_')
        $myfixedName = $myfixedName.replace('!','_')
        $myfixedName = $myfixedName.replace('/','_')
        $myfixedName = $myfixedName.replace('%','_')
        $Outfilename = $COutput_path+"$myfixedName.xml"

        Write-Output("Condition: {0}" -f $myfixedName)
        $xmlWriter = [System.Xml.XmlWriter]::Create($Outfilename)
        $Condition.Serialize($xmlWriter)
        $xmlWriter.Close()
    }
}
else
{
    Write-Output "Could Not Connect to PolicyStore"
}


# Return to Base
set-location $BaseFolder
