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
Write-Host  -f Yellow -b Black "14 - Service Broker"
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
if ($serverauth -eq "win")
{
    $srv   = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($SQLInstance)
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $SQLInstance
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)
}

$db = New-Object ("Microsoft.SqlServer.Management.SMO.Database")


# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	        = $true;
$scripter.Options.ScriptData 	        = $false;
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


# Export Endpoints (Not part of the Database/Servce Broker Setup, but the Server Object, AKA Endpoint is a TCP Listener)
foreach ($Endpoint in $srv.Endpoints)
{
    # Skip System Endpoints
    if ($Endpoint.id -lt 65535) {continue}

    $strmyFixedEndPointName = $Endpoint.Name.Replace('/','-')
    $strmyBrokerObjName = "Broker_Endpoint_"+$strmyFixedEndPointName+".sql"    
    $strmyBObj = $Endpoint.script()
    $output_path = "$BaseFolder\$SQLInstance\14 - Service Broker\"+$strmyBrokerObjName
    $strmyBObj | out-file $output_path -Force -encoding ascii
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
   
    # Skip Offline Databases (SMO still enumerates them, but we cant retrieve the objects)
    if ($sqlDatabase.Status -ne 'Normal')     
    {
        Write-Output ("Skipping Offline: {0}" -f $sqlDatabase.Name)
        continue
    }

    # Init Counter
    $anyfound = $false
         
    # Message Types
    foreach($MsgType1 in $db.ServiceBroker.MessageTypes)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType1.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_MsgType_"+$fixedObjName+".sql"
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

    # Contracts
    foreach($MsgType2 in $db.ServiceBroker.ServiceContracts)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType2.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Contract_"+$fixedObjName+".sql"
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

    # Queues
    foreach($MsgType3 in $db.ServiceBroker.Queues)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType3.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Queue_"+$fixedObjName+".sql"
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

    # Services
    foreach($MsgType4 in $db.ServiceBroker.Services)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType4.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Service_"+$fixedObjName+".sql"
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

    # Routes
    foreach($MsgType5 in $db.ServiceBroker.Routes)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType5.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Route_"+$fixedObjName+".sql"
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


    # Remote Service Bindings
    foreach($MsgType6 in $db.ServiceBroker.RemoteServiceBindings)
    {
        # Script out objects for each DB
        $strmyBrokerMsgTypeName = $MsgType6.Name
        $fixedObjName = $strmyBrokerMsgTypeName.replace('/','-')
        $strmyBrokerMsgType = $fixedDBName+"_Broker_Remote_Service_Binding_"+$fixedObjName+".sql"
        $strmyBObj = $MsgType6.script()
        $output_path = $DB_Broker_output_path+"\"+$strmyBrokerMsgType

        
        # Not system Objects
        
        if ($MsgType6.Name -ne "AutoCreatedLocal")
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



# Return To Base
set-location $BaseFolder
