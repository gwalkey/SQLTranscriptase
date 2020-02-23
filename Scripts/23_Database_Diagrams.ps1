<#
.SYNOPSIS
    Gets the Database Diagrams from the target server
	
.DESCRIPTION
   Creates INSERT Statements into [database].[dbo].[sysdiagrams]

.EXAMPLE
    23_Database_Diagrams.ps1 localhost
	
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
Write-Host  -f Yellow -b Black "23 - Database Diagrams"
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

# Get Major Version Only
[int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

switch ($ver)
{
    7  {Write-Output "SQL Server 7"}
    8  {Write-Output "SQL Server 2000"}
    9  {Write-Output "SQL Server 2005"}
    10 {Write-Output "SQL Server 2008/R2"}
    11 {Write-Output "SQL Server 2012"}
    12 {Write-Output "SQL Server 2014"}
    13 {Write-Output "SQL Server 2016"}
    14 {Write-Output "SQL Server 2017"}
	15 {Write-Output "SQL Server 2019"}
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
$output_path = "$BaseFolder\$SQLInstance\23 - Database Diagrams\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases - unless you actually installed some USER Tables here- bad monkey
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}


    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\23 - Database Diagrams\$fixedDBname"
               
    # Get Diagrams
    $sqlCMD2 = 
    "
    USE [$fixedDBName];
    
    if (select 1 from sys.tables where name = 'sysdiagrams')=1
    begin
	    select [name], [principal_id], [version], [definition] from dbo.sysdiagrams
    end

    "

    if ($serverauth -eq "win")
    {
    	$sqlresults2 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2
    }
    else
    {
        $sqlresults2 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD2 -User $myuser -Password $mypass
    }

    # None found? Skip
    if (!$sqlresults2) {continue}

    Write-Output ("Scripting out Database Diagrams for: {0}" -f $fixedDBName)
    
    
    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


    foreach ($diagram in $sqlresults2)
    {        
        $DName = $diagram.name

        $sqlCMD3 = "`
        Use ["+$sqlDatabase.Name+"];"+
        "

        select
    	'insert into dbo.sysdiagrams ([name], [principal_id], [version], [definition]) values ('+
    	char(39)+[name]+ char(39)+', '+
    	convert(nvarchar,[principal_id])+', '+
    	convert(nvarchar,[Version])+', '+
    	'0x'+convert(varchar(max),[definition],2) + 
    	')' as 'column1'
        from  dbo.sysdiagrams
        where [name] = '$DName'
        "

        # Dump Diagrams
        if ($serverauth -eq "win")
        {
            $sqlresults3 = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3
        }
        else
        {     
            $sqlresults3 = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $sqlCMD3 -User $myuser -Password $mypass
        }
        # Write Out
        $myoutputfile = $output_path+"\"+$DName+".sql"
        $sqlresults3.column1 | out-file -FilePath $myoutputfile -append -encoding ascii -width 10000000
        
    } 

}

# Return To Base
set-location $BaseFolder
