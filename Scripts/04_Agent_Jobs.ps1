<#
.SYNOPSIS
    Scripts out all SQL Agent Jobs
	
.DESCRIPTION
   Writes the SQL Agent Jobs out to the "04 - Agent Jobs" folder
   One file per job 
   and a SingleFile with All Jobs
   
.EXAMPLE
    04_Agent_Jobs.ps1 localhost
	
.EXAMPLE
    04_Agent_Jobs.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK
	https://github.com/gwalkey	
	
#>

[CmdletBinding()]
Param(
  [string]$SQLInstance='c0sqlmon',
  [string]$myuser,
  [string]$mypass
)

# Load Common Modules and .NET Assemblies
try
{
    Import-Module ".\SQLTranscriptase.psm1" -ErrorAction Stop
}
catch
{
    Throw('SQLTranscriptase.psm1 not found')
}

try
{
    Import-Module ".\LoadSQLSmo.psm1"
}
catch
{
    Throw('LoadSQLSmo.psm1 not found')
}

LoadSQLSMO

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "04 - Agent Jobs"
Write-Output("Server: [{0}]" -f $SQLInstance)

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

[int]$ver = GetSQLNumericalVersion $myver



# Check for Express version and exit - No Agent exists
$EditionSQL = "SELECT SERVERPROPERTY('Edition')"
# Run Query
if ($serverauth -eq "win")
{
    try
    {
        $Edition = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -ErrorAction Stop
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
        $Edition = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $EditionSQL -User $myuser -Password $mypass -ErrorAction Stop
    }
    catch
    {
        Throw("Error Connecting to SQL: {0}" -f $error[0])
    }
}

if ($Edition -ne $null )
{
    if ($edition.column1 -match "Express")
    {
        Write-Output ("Skipping '{0}'" -f $Edition.column1)
        exit
    }    
}


# SMO Connection
$server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLInstance

# Using SQL Auth?
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1)
{
	$server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
	$server.ConnectionContext.Password=$mypass
	Write-Output "Using SQL Auth"
}
else
{
	Write-Output "Using Windows Auth"
}

$ErrorActionPreference='Stop'
try
{
    $jobs = $server.JobServer.Jobs
}
catch
{
    Write-Output('Cant access the SMO Jobs Object')
    exit
}
$ErrorActionPreference='Continue'
 
# Create Output Folders
$fullfolderPathEn = "$BaseFolder\$sqlinstance\04 - Agent Jobs\Enabled"
if(!(test-path -path $fullfolderPathEn))
{
	mkdir $fullfolderPathEn | Out-Null
}

$fullfolderPathDis = "$BaseFolder\$sqlinstance\04 - Agent Jobs\Disabled"
if(!(test-path -path $fullfolderPathDis))
{
	mkdir $fullfolderPathDis | Out-Null
}

$SingleFilename = "$BaseFolder\$sqlinstance\04 - Agent Jobs\Alljobs.sql"
$SinglejobContents = ""

# Clear out putput folders
Get-ChildItem -Path $fullfolderPathEn -Include * -File -Recurse | remove-item -Confirm:$false
Get-ChildItem -Path $fullfolderPathDis -Include * -File -Recurse | remove-item -Confirm:$false

$jobcount = $server.JObserver.jobs.count
 
 # Export with filename fixups
 # Enabled Jobs First
if ($jobs -ne $null)
{
    Write-Output "Exporting Agent Jobs:"

    ForEach ( $job in $jobs )
    {
        $myjobname = $job.Name
        $myjobname = $myjobname.Replace('\', '-')
        $myjobname = $myjobname.Replace('/', '-')
        $myjobname = $myjobname.Replace('&', '-')
        $myjobname = $myjobname.Replace(':', '-')
        $myjobname = $myjobname.replace('[','(')
        $myjobname = $myjobname.replace(']',')')
        $myjobname = $myjobname.replace('*','_')
        $myjobname = $myjobname.replace('**','__')
        
        if ($job.Isenabled)
        {
            $FileName = "$fullfolderPathEn\$myjobname.sql"
        }
        else
        {
            $FileName = "$fullfolderPathDis\$myjobname.sql"
        }
        
        Write-Output('{0}' -f $myjobname)
        try
        {
            $jobContents = $job.Script()

            # Append this job to the AllJobs string
            $SinglejobContents = $SinglejobContents + $jobContents+ "`r`nGO`r`n`r`n"     

            # Export individual job contents
            $jobContents| Out-File -FilePath $FileName
        }
        catch
        {
            Write-Output('Error: [{0}]' -f $Error[0])
            Write-Output('FileName: [{0}]' -f $FileName)
        }
        

    }

    # Export Alljobs contents
    $SinglejobContents | Out-File -FilePath $SingleFilename

    Write-Output ("{0} Jobs Exported" -f $jobCount)
}
else
{
    Write-Output "No Agent Jobs Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Jobs Found.txt"
    Set-Location $BaseFolder
    exit
}

# Return To Base
Set-Location $BaseFolder
