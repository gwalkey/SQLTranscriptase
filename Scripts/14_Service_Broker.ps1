<#
.SYNOPSIS
    Gets the SQL Service Broker Objects on the target server
	
.DESCRIPTION
   Writes the SQL Service Broker Objects out to the "14 - Service Broker" folder   
   There is one subfolder for each Database having Service Boker Objects enabled
   These objects are:
   Contracts
   Messages
   Queues   
   Services
   Routes
   
.EXAMPLE
    14_Service_Broker.ps1 localhost
	
.EXAMPLE
    14_Service_Broker.ps1 server01 sa password


.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES

	
.LINK

	
#>


Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "14 - Service Broker"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./14_Service_Broker.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
		
			$scripter.Options.FileName = $outDir + $schemaPrefix + $o.Name + ".sql"			
			$scripter.EnumScript($o)
		}
	}
}


# Set Local Vars
$server = $SQLInstance

if ($serverauth -eq "win")
{
    $srv   = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

$db = New-Object ("Microsoft.SqlServer.Management.SMO.Database")


# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	        = $true;
$scripter.Options.ScriptData 	        = $false;

#Exclude GOs after every line
$scripter.Options.NoCommandTerminator 	= $false;
$scripter.Options.ToFileOnly 			= $true
$scripter.Options.AllowSystemObjects 	= $false
$scripter.Options.Permissions 			= $true
$scripter.Options.DriAllConstraints 	= $true
$scripter.Options.SchemaQualify 		= $true
$scripter.Options.AnsiFile 				= $true
$scripter.Options.WithDependencies		= $false
$scripter.Options.SchemaQualifyForeignKeysReferences = $true

$scripter.Options.Indexes 				= $true
$scripter.Options.DriIndexes 			= $true
$scripter.Options.DriClustered 			= $true
$scripter.Options.DriNonClustered 		= $true
$scripter.Options.NonClusteredIndexes 	= $true
$scripter.Options.ClusteredIndexes 		= $true
$scripter.Options.FullTextIndexes 		= $true
$scripter.Options.IncludeHeaders        = $false

$scripter.Options.EnforceScriptingOptions 	= $true



# Create output folder
$output_path = "$BaseFolder\$SQLInstance\14 - Service Broker\"
if(!(test-path -path $output_path))
    {
        mkdir $output_path | Out-Null
    }

# -----------------------
# iterate over each DB
# -----------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB','SSISDB') {continue}

    # Script out objects for each DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $DB_Broker_output_path = "$BaseFolder\$SQLInstance\14 - Service Broker\$fixedDBname"
   
    $anyfound = $false
         
                
    # 1) 
    # Message Types
    foreach($MsgType1 in $db.ServiceBroker.MessageTypes)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType1.Name
        $strmyBrokerMsgType = $fixedDBName+"_Broker_MsgType_"+$strmyBrokerMsgTypeName+".sql"
        $strmyBObj = $MsgType1.script()
        $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

        # Not system Objects
        if (!$MsgType1.IsSystemObject)
        {
            # Only create path if something to write
            if(!(test-path -path $DB_Broker_output_path))
            {
                mkdir $DB_Broker_output_path | Out-Null
            }
            $strmyBObj | out-file $output_path -Force -encoding ascii
            $anyfound = $true
        }
    }

    # 2) 
    # Contracts
    foreach($MsgType2 in $db.ServiceBroker.ServiceContracts)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType2.Name
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Contract_"+$strmyBrokerMsgTypeName+".sql"
        $strmyBObj = $MsgType2.script()
        $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

        # Not system Objects
        if (!$MsgType2.IsSystemObject)
        {
            # Only create path if something to write
            if(!(test-path -path $DB_Broker_output_path))
            {
                mkdir $DB_Broker_output_path | Out-Null
            }
            $strmyBObj | out-file $output_path -Force -encoding ascii
            $anyfound = $true
        }
    }

    # 3)
    # Queues
    foreach($MsgType3 in $db.ServiceBroker.Queues)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType3.Name
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Queue_"+$strmyBrokerMsgTypeName+".sql"
        try
        {
            $strmyBObj = $MsgType3.script()
        
            $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

            # Not system Objects
            if (!$MsgType3.IsSystemObject)
            {
                # Only create path if something to write
                if(!(test-path -path $DB_Broker_output_path))
                {
                    mkdir $DB_Broker_output_path | Out-Null
                }
                $strmyBObj | out-file $output_path -Force -encoding ascii
                $anyfound = $true
            }
        }
        catch
        {
            #Write-Output "Skipping system queue $strmyBrokerMsgTypeName"
        }
    }

    # 4)
    # Services
    foreach($MsgType4 in $db.ServiceBroker.Services)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType4.Name
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Service_"+$strmyBrokerMsgTypeName+".sql"
        $strmyBObj = $MsgType4.script()
        $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

        # Not system Objects
        if (!$MsgType4.IsSystemObject)
        {
            # Only create path if something to write
            if(!(test-path -path $DB_Broker_output_path))
            {
                mkdir $DB_Broker_output_path | Out-Null
            }
            $strmyBObj | out-file $output_path -Force -encoding ascii
            $anyfound = $true
        }
    }

    # 5)
    # Routes
    foreach($MsgType5 in $db.ServiceBroker.Routes)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType5.Name
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Route_"+$strmyBrokerMsgTypeName+".sql"
        $strmyBObj = $MsgType5.script()
        $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

        
        # Not system Objects
        
        if ($MsgType5.Name -ne "AutoCreatedLocal")
        {
            # Only create path if something to write
            if(!(test-path -path $DB_Broker_output_path))
            {
                mkdir $DB_Broker_output_path | Out-Null
            }
            $strmyBObj | out-file $output_path -Force -encoding ascii
            $anyfound = $true
        }
        
    }

if ($anyfound-eq $true)
{
    Write-Output "Broker Objects written for $fixedDBName"
}


# Process Next Database
}



# finish
set-location $BaseFolder

