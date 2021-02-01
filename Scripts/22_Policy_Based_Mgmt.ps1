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

    Feb 1, 2021 - Switched to building SQL statements with SQL as the SMO libraries are trash
	
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

# Init
Set-StrictMode -Version latest;
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName
Write-Host  -f Yellow -b Black "22 - Policy Based Mgmt Objects"
Write-Output("Server: [{0}]" -f $SQLInstance)

# Server connection check
$SQLCMD1 = "select serverproperty('productversion') as 'Version'"
try
{
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        Write-Output "Testing SQL Auth"        
        $myver = ConnectSQLAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop| Select-Object -ExpandProperty Version
        $serverauth="sql"
    }
    else
    {
        Write-Output "Testing Windows Auth"
		$myver = ConnectWinAuth -SQLInstance $SQLInstance -Database "master" -SQLExec $SQLCMD1 -ErrorAction Stop | Select-Object -ExpandProperty Version
        $serverauth = "win"
    }

    if($null -eq $myver)
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

# Get Conditions
$SQLCMD1="SELECT * FROM [msdb].[dbo].[syspolicy_conditions] WHERE is_system=0"
if ($serverauth -eq 'win')
{
    $Conditions = Connect-InternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD1 -ErrorAction Stop  
}
else {
    $Conditions = Connect-ExternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD1 -User $myuser -Password $mypass -ErrorAction Stop  
}


# Get Policies
$SQLCMD2="
SELECT 
    c.name AS 'condition_name',
    a.name AS 'policy_category',
	p.*	
FROM 
	msdb.dbo.syspolicy_policies P
LEFT JOIN
	dbo.syspolicy_conditions C
ON 
    c.condition_id = p.condition_id
LEFT JOIN
	[syspolicy_policy_categories] A
ON 
	A.policy_category_id = P.policy_category_id   
WHERE 
	c.is_system=0
"

if ($serverauth -eq 'win')
{
    $Policies = Connect-InternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD2 -ErrorAction Stop  
}
else {
    $Policies = Connect-ExternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD2 -User $myuser -Password $mypass -ErrorAction Stop  
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
if ($null -ne $Conditions)
{
    Write-Output "Exporting PBM Conditions..."
    
    foreach($Condition in $Conditions)
    {
        $myCName =     $Condition.Name
        $myfixedName = $myCName.replace('\','_')
        $myfixedName = $myfixedName.replace('!','_')
        $myfixedName = $myfixedName.replace('/','_')
        $myfixedName = $myfixedName.replace('%','_')
        $Outfilename = $COutput_path+"$myfixedName.sql"
        "" | out-file -filepath $Outfilename -force -Encoding default

        # Build SQL Statement
        "EXEC msdb.dbo.sp_syspolicy_add_condition" | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @name=N'"+$condition.name+"',"  | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @description=N'"+$condition.description+"',"  | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @facet=N'"+$condition.facet+"',"  | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @expression=N'"+$condition.expression+"',"  | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @is_name_condition="+$condition.is_name_condition+","  | Out-File -FilePath $Outfilename -Append -Encoding default
        "     @obj_name=N'"+$condition.is_name_condition+"'`r`n"  | Out-File -FilePath $Outfilename -Append -Encoding default

       
    }
}

if ($null -ne $Policies)
{
    Write-Output "Exporting PBM Policies..."
    
    foreach($Policy in $Policies)
    {
        $myPName =     $Policy.Name
        $myfixedName = $myPName.replace('\','_')
        $myfixedName = $myfixedName.replace('!','_')
        $myfixedName = $myfixedName.replace('/','_')
        $myfixedName = $myfixedName.replace('%','_')
        $Outfilename = $POutput_path+"$myfixedName.sql"
        "" | out-file -filepath $Outfilename -force -Encoding default

        # Build SQL Statement
        $Policy_id = $policy.policy_id

        # sp_syspolicy_add_object_set 
        $SQLCMD3 = 'SELECT * FROM [msdb].[dbo].[syspolicy_object_sets] WHERE object_set_id='+$Policy_ID
        if ($serverauth -eq 'win')
        {
            $Syspolicy_object_sets = Connect-InternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD3
        }
        else {
            $Syspolicy_object_sets = Connect-ExternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD3 -User $myuser -Password $mypass -ErrorAction Stop
        }
        if ($null -ne $Syspolicy_object_sets)
        {
            $object_set_name = $Syspolicy_object_sets.object_set_name
            $facet_name = $Syspolicy_object_sets.facet_name

            "DECLARE @object_set_id INT;" | Out-File -FilePath $Outfilename -Append -Encoding default
            "EXEC msdb.dbo.sp_syspolicy_add_object_set @object_set_name = N'"+$object_set_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @facet = N'"+$facet_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @object_set_id = @object_set_id OUTPUT;" | Out-File -FilePath $Outfilename -Append -Encoding default
            "SELECT @object_set_id;`r`n" | Out-File -FilePath $Outfilename -Append -Encoding default
        }
        
        
        # sp_syspolicy_add_target_set
        $SQLCMD4 = 'SELECT * FROM [msdb].[dbo].[syspolicy_target_sets] WHERE object_set_id='+$Policy_ID
        if ($serverauth -eq 'win')
        {
            $Syspolicy_target_sets = Connect-InternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD4
        }
        else {
            $Syspolicy_target_sets = Connect-ExternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD4 -User $myuser -Password $mypass -ErrorAction Stop
        }
        if ($null -ne $Syspolicy_target_sets)
        {
            $target_set_id = $Syspolicy_target_sets.target_set_id
            $target_type_skeleton = $Syspolicy_target_sets.type_skeleton
            $target_set_type = $Syspolicy_target_sets.type
            $target_set_enabled = $Syspolicy_target_sets.enabled

            "DECLARE @target_set_id INT;" | Out-File -FilePath $Outfilename -Append -Encoding default
            "EXEC msdb.dbo.sp_syspolicy_add_target_set @object_set_name = N'"+$object_set_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @type_skeleton = N'"+$target_type_skeleton+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @type = N'"+$target_set_type+"',"| Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @enabled = "+$target_set_enabled+","| Out-File -FilePath $Outfilename -Append -Encoding default
            "                                          @target_set_id = @target_set_id OUTPUT;"| Out-File -FilePath $Outfilename -Append -Encoding default
            "SELECT @target_set_id;`r`n"| Out-File -FilePath $Outfilename -Append -Encoding default
        }
        

        # sp_syspolicy_add_target_set_level
        $SQLCMD5 = 'SELECT * FROM [msdb].[dbo].[syspolicy_target_set_levels] WHERE target_set_id='+$target_set_id
        if ($serverauth -eq 'win')
        {
            $Syspolicy_target_set_levels = Connect-InternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD5
        }
        else {
            $Syspolicy_target_set_levels = Connect-ExternalSQLServer -SQLInstance $SQLInstance -Database 'msdb' -SQLExec $SQLCMD5 -User $myuser -Password $mypass -ErrorAction Stop
        }
        if ($null -ne $Syspolicy_target_set_levels)
        {
            $target_set_level_type_skeleton = $Syspolicy_target_set_levels.type_skeleton
            $target_set_level_level_name = $Syspolicy_target_set_levels.level_name
            $target_set_level_condition_id = $Syspolicy_target_set_levels.condition_id

            "EXEC msdb.dbo.sp_syspolicy_add_target_set_level @target_set_id = @target_set_id," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                                @type_skeleton = N'"+$target_set_level_type_skeleton+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                                @level_name = N'"+$target_set_level_level_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                                @condition_name = N'"+$target_set_level_condition_id+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
            "                                                @target_set_level_id = 0;`r`n" | Out-File -FilePath $Outfilename -Append -Encoding default            
            
        }

        "GO`r`n" | Out-File -FilePath $Outfilename -Append -Encoding default

        # sp_syspolicy_add_policy  
        $policy_enabled = $policy.is_enabled
        
        "DECLARE @policy_id INT;" | Out-File -FilePath $Outfilename -Append -Encoding default
        "EXEC msdb.dbo.sp_syspolicy_add_policy @name = N'"+$policy.Name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @condition_name = N'"+$policy.condition_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @policy_category = N'"+$policy.policy_category+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @description = N'"+$policy.description+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @help_text = N'"+$policy.help_text+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @help_link = N'"+$policy.help_link+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @schedule_uid = N'"+$policy.schedule_uid+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @execution_mode = "+$policy.execution_mode+"," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @is_enabled = "+$policy_enabled+"," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @policy_id = @policy_id OUTPUT," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @root_condition_name = N''," | Out-File -FilePath $Outfilename -Append -Encoding default
        "                                      @object_set = N'"+$object_set_name+"'," | Out-File -FilePath $Outfilename -Append -Encoding default
        "SELECT @policy_id;" | Out-File -FilePath $Outfilename -Append -Encoding default
        "GO`r`n" | Out-File -FilePath $Outfilename -Append -Encoding default
    }
}

# Return to Base
set-location $BaseFolder