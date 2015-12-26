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

	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "24 - Plan Guides"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-Host -f yellow "Usage: ./24_Plan_Guides.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}

# Working
Write-Output "Server $SQLInstance"

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
$server 	= $SQLInstance

if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
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

    # Skip System Databases - unless you actually installed SOME DLLs here!- bad monkey
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}


    # Strip brackets from DBname
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $output_path = "$BaseFolder\$SQLInstance\24 - Plan Guides\$fixedDBname"
               
    # Get Diagrams
    $mySQLquery = 
    "
    USE $fixedDBName
    GO
    select * from  sys.plan_guides
    "

    # Run SQL
    $results = @()
    if ($serverauth -eq "win")
    {    
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -QueryTimeout 10 -erroraction SilentlyContinue -MaxCharLength 100000000
    }
    else
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query $mySQLquery -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue -MaxCharLength 100000000
    }

    # Any results?
    if ($results)
    {
        Write-Output ("Scripting out Plan Guides for: {0}" -f $fixedDBName)
    }
    else
        {continue}
    
    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


    foreach ($pg in $results)
    {        
        $PName = $pg.name

        $pquery = "`
        Use "+$sqlDatabase.Name+";"+
        "

        select 
	        'exec sp_create_plan_guide '+
	        '@name=N'+char(39)+'['+[name]+']'+char(39)+', '+
	        '@stmt=N'+char(39)+[query_text]+char(39)+', '+
	        '@type=N'+char(39)+[scope_type_desc]+char(39)+', '+
	        '@module_or_batch=N'+char(39)+isnull([scope_batch],'null')+char(39)+', '+
	        '@params='+iif([parameters] is null,'null', 'N'+char(39)+[parameters]+char(39))+', '+
	        '@hints=N'+char(39)+[hints]+char(39) as 'column1'
        from 
	        sys.plan_guides
           where [name] = '$PName'
        "

                
        # Dump Plan Guides
        if ($serverauth -eq "win")
        {
            $presults = Invoke-Sqlcmd -MaxCharLength 100000000 -ServerInstance $SQLInstance -Query $pquery 
        }
        else
        {     
            $presults = Invoke-Sqlcmd -MaxCharLength 100000000 -ServerInstance $SQLInstance -Query $pquery -Username $myuser -Password $mypass
        }
        # Write Out
        $myoutputfile = $output_path+"\"+$PName+".sql"
        $presults.column1 | out-file -FilePath $myoutputfile -append -encoding ascii -width 10000000
        
    } 
            

# Process Next Database
}
c:


# finish
set-location $BaseFolder



