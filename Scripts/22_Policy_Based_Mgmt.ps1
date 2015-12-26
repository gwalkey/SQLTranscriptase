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

	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "22 - Policy Based Mgmt Objects"

# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./22_Policy_Based_Mgmt.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Load Additional Assemblies
$dmfver = $null;
$dmfdll = "C:\Program Files (x86)\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
if((test-path -path $dmfdll))
{
    $dmfver = 2008
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\100\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
}

$dmfdll = "C:\Program Files (x86)\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
if((test-path -path $dmfdll))
{
    $dmfver = 2012
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
}

$dmfdll = "C:\Program Files (x86)\Microsoft SQL Server\120\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
if((test-path -path $dmfdll))
{
    $dmfver = 2014
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\120\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
}

$dmfdll = "C:\Program Files (x86)\Microsoft SQL Server\130\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
if((test-path -path $dmfdll))
{
    $dmfver = 2016
    add-type -path "C:\Program Files (x86)\Microsoft SQL Server\130\SDK\Assemblies\Microsoft.SqlServer.Dmf.dll"
}

If (!($dmfver))
{
    Write-Output "Microsoft.SqlServer.Dmf.dll not found, exiting"
    exit
}


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



# Set Local Vars
$server = $SQLInstance

# Connect
if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $conn = New-Object Microsoft.SQlServer.Management.Sdk.Sfc.SqlStoreConnection("server='$sqlinstance';Trusted_Connection=true")
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $conn = New-Object Microsoft.SQlServer.Management.Sdk.Sfc.SqlStoreConnection("server='$sqlinstance';Trusted_Connection=false; User Id=$myuser; Password=$mypass")
}


# Prep Output Folder
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

# Scripter function
function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"
            try
            {                
                $urn = new-object Microsoft.SQlserver.Management.sdk.sfc.urn($o.Urn);
                $scripter.Script($urn)
            }
            catch
            {
                $msg = "Cannot script this element:"+$o
                Write-Output $msg
            }
		}
	}
}


Write-Output "Exporting PBM Policies and Conditions..."

# Script Out Policies
$PolicyStore = New-Object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)
$MyP = $PolicyStore.Policies | Where-Object { -not $_.IsSystemObject }

foreach($policy in $MyP)
{
    $myPName = $Policy.Name
    $myfixedName = $myPName.replace('\','_')
    $myfixedName = $myfixedName.replace('!','_')
    $myfixedName = $myfixedName.replace('/','_')
    $myfixedName = $myfixedName.replace('%','_')
    $Outfilename = $POutput_path+"$myfixedName.xml"
    "Policy: $myfixedName"
    $xmlWriter = [System.Xml.XmlWriter]::Create($Outfilename)
    $policy.Serialize($xmlWriter)
    $xmlWriter.Close()
}


# Script out Conditions
#$Cond_Store=New-Object Microsoft.SqlServer.Management.Dmf.PolicyCondition ($PolicyStore,'TheConditions')
$myC = $PolicyStore.Conditions | Where-Object { -not $_.IsSystemObject }

foreach($Condition in $myC)
{
    $myCName = $Condition.Name
    $myfixedName = $myCName.replace('\','_')
    $myfixedName = $myfixedName.replace('!','_')
    $myfixedName = $myfixedName.replace('/','_')
    $myfixedName = $myfixedName.replace('%','_')
    $Outfilename = $COutput_path+"$myfixedName.xml"
    "Condition: $myfixedName"
    $xmlWriter = [System.Xml.XmlWriter]::Create($Outfilename)
    $Condition.Serialize($xmlWriter)
    $xmlWriter.Close()
}

# Return Home
set-location $BaseFolder
