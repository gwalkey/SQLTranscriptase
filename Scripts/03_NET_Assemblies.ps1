<#
.SYNOPSIS
    Gets the .NET Assemblies registered on the target server
	
.DESCRIPTION
   Writes the .NET Assemblies out to the "03 - NET Assemblies" folder
   One folder per Database
   One file for each registered DLL
   CREATE ASSEMBLY with the binary as a HEX STRING
   
.EXAMPLE
    03_NET_Assemblies.ps1 localhost
	
.EXAMPLE
    03_NET_Assemblies.ps1 server01 sa password

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
Write-Host  -f Yellow -b Black "03 - .NET Assemblies"
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


# New UP SMO Object
if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
}



# Create output folder
$output_path = "$BaseFolder\$SQLInstance\03 - NET Assemblies\"
if(!(test-path -path $output_path))
{
    mkdir $output_path | Out-Null
}

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases - unless you actually installed some DLLs in those!- bad monkey
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}
    
    # Skip Offline Databases (SMO still enumerates them, but we cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\03 - NET Assemblies\$fixedDBname"
    
               
    # Get Assemblies
    $SQLCMD2 = 
    "
    USE [$fixedDBName]

    SELECT  
    a.name as [AName],
    af.name as [DLL],
    'CREATE ASSEMBLY [' + a.name + '] FROM 0x' +
    convert(varchar(max),af.content,2) +
     ' WITH PERMISSION_SET=' +
    case 
	    when a.permission_set=1 then 'SAFE' 
	    when a.permission_set=2 then 'EXTERNAL_ACCESS' 
	    when a.permission_set=3 then 'UNSAFE'
    end as 'Content'
    FROM sys.assemblies a
    INNER JOIN sys.assembly_files af ON a.assembly_id = af.assembly_id 
    WHERE a.name <> 'Microsoft.SqlServer.Types' 
    "

    # Run Query
    if ($serverauth -eq "win")
    {
        try
        {
            $sqlresults = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -ErrorAction Stop
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
            $sqlresults = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD2 -User $myuser -Password $mypass -ErrorAction Stop
        }
        catch
        {
            Throw("Error Connecting to SQL: {0}" -f $error[0])
        }
    }

    # Any results?
    try
    {
        if ($sqlresults.count -gt 0)
        {
            Write-Output ("Processing: {0}" -f $fixedDBName)
        }

        foreach ($assembly in $sqlresults)
        {        
            # One Sub for each DB
            if(!(test-path -path $output_path))
            {
                mkdir $output_path | Out-Null
            }
    
            $myoutputfile = $output_path+"\"+$assembly.AName+'.sql'        
            $myoutputstring = $assembly.Content
            $myoutputstring | out-file -FilePath $myoutputfile -encoding ascii -width 50000000
        }
    }
    catch 
    {
    } 
            

# Process Next Database
}


# Return To Base
set-location $BaseFolder



