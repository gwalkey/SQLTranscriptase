<#
.SYNOPSIS
    Gets any saved Plan Guides per Database from the target server
	
.DESCRIPTION
  Creates 'EXEC sp_create_plan_guide' Statements from [database].[sys].[plan_guides]

.EXAMPLE
    24_Plan_Guides.ps1 localhost
	
.EXAMPLE
    24_Plan Guides.ps1 localhost username password

.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
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
Write-Host  -f Yellow -b Black "24 - Plan Guides"
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



# New UP SQL SMO Object
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
$output_path = "$BaseFolder\$SQLInstance\24 - Plan Guides\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases - unless you actually installed some plan guides here- bad monkey
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}


    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\24 - Plan Guides\$fixedDBname"
               
    # Get Diagrams
    $sqlCMD1 = 
    "
    USE [$fixedDBName];
    
    select * from  sys.plan_guides;
    "

    if ($serverauth -eq "win")
    {
    	$sqlresults1 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1
    }
    else
    {
        $sqlresults1 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD1 -User $myuser -Password $mypass
    }

    # Any results?
    if ($sqlresults1 -eq $null) {continue}

    Write-Output ("Database: {0}" -f $fixedDBName)
    
    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


    foreach ($pg in $sqlresults1)
    {        
        $PlanName = $pg.Name
        $PlanID = $pg.Plan_guide_ID
        Write-Output('     Plan Name: {0}' -f $PlanName)

        $sqlCMD2 = "`
        Use ["+$sqlDatabase.Name+"];"+
        "

        select 
	        'exec sp_create_plan_guide '+char(13)+char(10)+
	        '@name=N'+char(39)+'['+[name]+']'+char(39)+', '+char(13)+char(10)+
	        '@stmt=N'+char(39)+replace([query_text],char(39),char(39)+char(39))+char(39)+', '+char(13)+char(10)+
	        '@type=N'+char(39)+[scope_type_desc]+char(39)+', '+char(13)+char(10)+
	        '@module_or_batch=N'+char(39)+isnull(replace([scope_batch],char(39),char(39)+char(39)),'null')+char(39)+', ' +char(13)+char(10)+
	        '@params='+iif([parameters] is null, 'null',char(39)+[parameters]+char(39))+', '+char(13)+char(10)+
	        '@hints='+iif([hints] is null, 'null',char(39)+[hints]+char(39))+char(13)+char(10) as 'column1'
        from 
	        sys.plan_guides
        where 
            [Plan_Guide_ID] = '$PlanID'
        "

                
        if ($serverauth -eq "win")
        {
        	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
        }
        else
        {
            $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
        }

        # Write Out
        $myoutputfile = $output_path+"\"+$PlanName+".sql"
        $sqlresults2.column1 | out-file -FilePath $myoutputfile -encoding ascii -width 10000000 -Force
        
    } 
            

# Process Next Database
}

# Return To Base
set-location $BaseFolder


