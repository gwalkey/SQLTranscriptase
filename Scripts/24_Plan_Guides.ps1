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
    USE $fixedDBName;
    
    select * from  sys.plan_guides;
    "

    # Catch Errors   
    $old_ErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    # Run SQL
    $results = @()
    if ($serverauth -eq "win")
    {

        # .NET Method
	    # Open connection and Execute sql against server using Windows Auth
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $mySQLquery
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null
        if ($DataSet.tables[0].Rows.count -gt 0)
        {
            $results = $DataSet.Tables[0].Rows
            # Close connection to sql server
	        $Connection.Close()
        }
        else
        {
            # Close connection to sql server
            $results = $null
	        $Connection.Close()
            continue
        }

    }
    else
    {

        # .NET Method
	    # Open connection and Execute sql against server
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $mySQLquery
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null
        if ($DataSet.tables[0].Rows.count -gt 0)
        {
            $results = $DataSet.Tables[0].Rows
            # Close connection to sql server
	        $Connection.Close()
            
        }
        else
        {
            # Close connection to sql server
            $results = $null
	        $Connection.Close()
            continue
        }  


    }

    # Any results?
    if (!$results) 
        {continue}
    else
    {
        Write-Output ("Scripting out Plan Guides for: {0}" -f $fixedDBName)
    }

    
    # One Output folder per DB
    if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }


    foreach ($pg in $results)
    {        
        $PlanName = $pg.Name
        $PlanID = $pg.Plan_guide_ID

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
           where [Plan_Guide_ID] = '$PlanID'
        "

                
        # Dump Plan Guides
        if ($serverauth -eq "win")
        {

            # .NET Method
	        # Open connection and Execute sql against server using Windows Auth
	        $DataSet = New-Object System.Data.DataSet
	        $SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	        $Connection = New-Object System.Data.SqlClient.SqlConnection
	        $Connection.ConnectionString = $SQLConnectionString
	        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	        $SqlCmd.CommandText = $pquery
	        $SqlCmd.Connection = $Connection
	        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	        $SqlAdapter.SelectCommand = $SqlCmd
    
	        # Insert results into Dataset table
	        $SqlAdapter.Fill($DataSet) | out-null
            if ($DataSet.tables[0].Rows.count -gt 0)
            {
                $presults = $DataSet.Tables[0].Rows
                # Close connection to sql server
	            $Connection.Close()
            }
            else
            {
                # Close connection to sql server
                $presults = $null
	            $Connection.Close()
                continue
            }

        }
        else
        {
            
            # .NET Method
	        # Open connection and Execute sql against server
	        $DataSet = New-Object System.Data.DataSet
	        $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	        $Connection = New-Object System.Data.SqlClient.SqlConnection
	        $Connection.ConnectionString = $SQLConnectionString
	        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	        $SqlCmd.CommandText = $pquery
	        $SqlCmd.Connection = $Connection
	        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	        $SqlAdapter.SelectCommand = $SqlCmd
    
    	    # Insert results into Dataset table
	        $SqlAdapter.Fill($DataSet) | out-null
            if ($DataSet.tables[0].Rows.count -gt 0)
            {
                $presults = $DataSet.Tables[0].Rows
                # Close connection to sql server
	            $Connection.Close()
            }
            else
            {
                # Close connection to sql server
                $presults = $null
	            $Connection.Close()
                continue
            }  


        }

        # Write Out
        $myoutputfile = $output_path+"\"+$PlanName+".sql"
        $presults.column1 | out-file -FilePath $myoutputfile -encoding ascii -width 10000000 -Force
        
    } 
            

# Process Next Database
}
c:


# Return To Base
set-location $BaseFolder

