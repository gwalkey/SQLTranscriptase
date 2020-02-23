<#
.SYNOPSIS
    Gets the SQL Server Analysis Services database objects on the target server
	
.DESCRIPTION
   Writes the SSAS Objects out to the "10 - SSAS" folder   
   Objects are written out in XMLA format for easy re-creation in SSMS
   Objects include:
   Cubes
   KPIs
   Measure Groups
   Partitions
   Dimensions
   Data Sources
   DataSource Views
   
.EXAMPLE
    10_SSAS_Objects.ps1 localhost
	
.EXAMPLE
    10_SSAS_Objects.ps1 server01 sa password


.Inputs
    ServerName\instance, [SQLUser], [SQLPassword]

.Outputs
	
.NOTES

    Download Provider Libraries
    https://docs.microsoft.com/en-us/azure/analysis-services/analysis-services-data-providers
    18.4.0.5

    https://docs.microsoft.com/en-us/bi-reference/tom/install-distribute-and-reference-the-tabular-object-model

    2016 and Newer, the namespaces have changed
    https://docs.microsoft.com/en-us/bi-reference/tom/list-existing-databases-on-a-tabular-server-analysis-services-amo-tom

    https://docs.microsoft.com/en-us/bi-reference/amo/developing-with-analysis-management-objects-amo
    AMO Namespace split after 2016

    [System.AppDomain]::CurrentDomain.GetAssemblies() | 
        Where-Object Location |
        Sort-Object -property Location |
        Out-GridView

.LINK
	https://github.com/gwalkey

#>

[CmdletBinding()]
Param(
  [string]$SQLInstance = "localhost",
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
Write-Host  -f Yellow -b Black "10 - SSAS Objects"
Write-Output("Server: [{0}]" -f $SQLInstance)

$dateStamp = (get-Date).ToString("yyyyMMdd")
$encoding = [System.Text.Encoding]::UTF8

# load the AMO and XML assemblies into the current session
try
{
    Add-Type –AssemblyName “Microsoft.AnalysisServices, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91” -ErrorAction Stop
    Add-Type –AssemblyName “Microsoft.AnalysisServices.Core, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91” -ErrorAction Stop
    Add-Type –AssemblyName “Microsoft.AnalysisServices.Tabular, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91” -ErrorAction Stop
}
catch
{
    Throw('Cant Find the AMO/TMO namespace libraries')
}

[System.Reflection.Assembly]::LoadWithPartialName("System.Xml") | out-null


# connect to the MD Server
try
{
    $svr = new-Object Microsoft.AnalysisServices.Server 
    $svr.Connect($SQLInstance) 
}
catch
{
    Write-Output('SSAS not running or cant connect to the MD server[{0}]' -f $SQLInstance)
    echo null > "$BaseFolder\$SQLInstance\10 - SSAS not running or cant connect.txt"
    exit
}

# Connect to the Tabular Server
try
{
    $Tsvr = New-Object Microsoft.AnalysisServices.Tabular.Server
    $Tsvr.Connect($SQLInstance) 
}
catch
{
    Write-Output('SSAS not running or cant connect to the Tabular Server [{0}]' -f $SQLInstance)
    echo null > "$BaseFolder\$SQLInstance\10 - SSAS not running or cant connect.txt"
    exit
}



# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\10 - SSAS\"
if ($svr.Databases.Count -ge 1)
{
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }
}

    
# Server Assemblies
$SvrAsmFolderPath = "$BaseFolder\$sqlinstance\10 - SSAS\Server Assemblies\"
if(!(test-path -path $SvrASmfolderPath))
{
    mkdir $SvrAsmFolderPath | Out-Null
}

try
{
    $SvrAssemblies=$svr.Assemblies
    foreach ($SAsm in $SvrAssemblies)
    {
        $xsa = new-object System.Xml.XmlTextWriter("$SvrAsmFolderPath\Server Assembly - $($SAsm.Name).xmla",$encoding)
        $xsa.Formatting = [System.Xml.Formatting]::Indented 
        [Microsoft.AnalysisServices.Scripter]::WriteCreate($xsa,$svr,$SAsm,$true,$true) 
        $xsa.Close() 

        # Write con
        Write-Output (" Server Assembly: {0}" -f $SAsm.Name)
    }
}
catch
{
    Write-Output "No Assemblies Found"
}


# HTML CSS
$head = "<style type='text/css'>"
$head+="
table
    {
        Margin: 0px 0px 0px 4px;
        Border: 1px solid rgb(190, 190, 190);
        Font-Family: Tahoma;
        Font-Size: 9pt;
        Background-Color: rgb(252, 252, 252);
    }
tr:hover td
    {
        Background-Color: rgb(150, 150, 220);
        Color: rgb(255, 255, 255);
    }
tr:nth-child(even)
    {
        Background-Color: rgb(242, 242, 242);
    }
th
    {
        Text-Align: Left;
        Color: rgb(150, 150, 220);
        Padding: 1px 4px 1px 4px;
    }
td
    {
        Vertical-Align: Top;
        Padding: 1px 4px 1px 4px;
    }
"
$head+="</style>"

# ----------------
# SSAS MD Objects
# ----------------
Write-Output "`r`nScripting out SSAS MD Database Objects..."
       
# MD Engine Config Settings
$RunTime = Get-date

# MD Server Properties
$Props=$svr.ServerProperties    
$myoutputfile4 = $FullFolderPath+"\SSAS_MD_Engine_Settings.html"
$myHtml1 = $Props | sort-object Name | select Name, Value, CurrentValue, DefaultValue, RequiresRestart, Type, Units, Category | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>SSAS MD Engine Settings</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "SSAS MD Engine Settings"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4
Write-Output (" Server MD Engine Config Settings: {0}" -f $Props.count)

$encoding = [System.Text.Encoding]::UTF8
foreach ($db in $svr.Databases) 
{         
    # Create SubFolder for each SSAS Database
    $SSASDBname = $db.Name
    $SSASDBFolderPath = $fullfolderPath+"$SSASDBname"
    if(!(test-path -path $SSASDBFolderPath))
    {
        mkdir $SSASDBFolderPath | Out-Null
    }
        
    # --------------------------------------------------------------------------------------------
    # If I am a MultiDimensional Cube-type DB, Process here, else handle Tabular Databases below
    # --------------------------------------------------------------------------------------------
    if ($Db.ModelType -eq "Multidimensional")
    {

        Write-Output ("Multidimensional Database: [{0}]" -f $db.Name)

        # 0) Script Out Entire Database as XMLA
        $xw = new-object System.Xml.XmlTextWriter("$SSASDBFolderPath\Full Database - $($db.Name).xmla",$encoding)
        $xw.Formatting = [System.Xml.Formatting]::Indented 
        [Microsoft.AnalysisServices.Scripter]::WriteCreate($xw,$svr,$db,$true,$true) 
        $xw.Close() 

        # Now, get each SSAS element: Cube, Measures, Dimensions, Partitions, Mining Structures, Roles, Assemblies, Data Sources, Data Source Views
        $CubeFolderPath = "$SSASDBFolderPath\Cubes"
        if(!(test-path -path $CubeFolderPath))
        {
            mkdir $CubeFolderPath | Out-Null
        }
        
        # 1) Cubes
        $Cubes=New-object Microsoft.AnalysisServices.Cube
        $Cubes=$db.cubes
        foreach ($cube in $cubes)
        {
            # Each Cube gets its own folder of Cubes, MeasureGroups and MGPartition objects
            $CubeName = $Cube.Name
            $Cube2FolderPath = "$CubeFolderPath\$CubeName"
            if(!(test-path -path $Cube2FolderPath))
            {
                mkdir $Cube2FolderPath | Out-Null
            }

            $xc = new-object System.Xml.XmlTextWriter("$Cube2FolderPath\Cube - $($cube.Name).xmla",$encoding)
            $xc.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xc,$svr,$cube,$true,$true) 
            $xc.Close() 

            # Write con
            Write-Output (" Cube: {0}, State:{1}, LastProcessed:{2}" -f $cube.name, $cube.state, $cube.lastprocessed)
        

            # 2) Measure Groups and Partitions
            $MGFolderPath = "$Cube2FolderPath\MeasureGroups"
            if(!(test-path -path $MGFolderPath))
            {
                mkdir $MGFolderPath | Out-Null
            }

            $MGroups=$cube.MeasureGroups
            foreach ($MG in $MGroups)
            {

                # Each Measure Group gets its own folder for Measure Group Partition objects
                $MGName = $MG.Name
                $MGPartFolderPath = "$MGFolderPath\$MGName"
                if(!(test-path -path $MGPartFolderPath))
                {
                    mkdir $MGPartFolderPath | Out-Null
                }

                $xm = new-object System.Xml.XmlTextWriter("$MGPartFolderPath\MeasureGroup - $($MG.Name).xmla",$encoding)
                $xm.Formatting = [System.Xml.Formatting]::Indented 
                [Microsoft.AnalysisServices.Scripter]::WriteCreate($xm,$svr,$MG,$true,$true) 
                $xm.Close() 

                # Write con
                Write-Output ("  Measure Group: {0}" -f $MG.Name)
                
                # 3) Measure Group Partitions
                foreach ($partition in $mg.Partitions)
                {
                    $xmgp = new-object System.Xml.XmlTextWriter("$MGPartFolderPath\Measure Group Partition - $($partition.Name).xmla",$encoding)
                    $xmgp.Formatting = [System.Xml.Formatting]::Indented 
                    [Microsoft.AnalysisServices.Scripter]::WriteCreate($xmgp,$svr,$partition,$true,$true) 
                    $xmgp.Close() 
    
                    # Write con
                    Write-Output ("   Measure Group Partition: {0}" -f $partition.Name)
                }
                        
            }

        }

        # 4) Dimensions
        $DimFolderPath = "$SSASDBFolderPath\Dimensions"
        if(!(test-path -path $DimFolderPath))
        {
            mkdir $DimFolderPath | Out-Null
        }

        $Dimensions=New-object Microsoft.AnalysisServices.Dimension
        $Dimensions=$db.Dimensions
        foreach ($dim in $Dimensions)
        {
            $xd = new-object System.Xml.XmlTextWriter("$DimFolderPath\Dimension - $($dim.Name).xmla",$encoding)
            $xd.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xd,$svr,$dim,$true,$true) 
            $xd.Close() 

            # Write con
            Write-Output (" Dimension: {0}" -f $Dim.Name)
        }

        # 5) Mining Structures
        $MiningFolderPath = "$SSASDBFolderPath\MiningStructures"
        if(!(test-path -path $MiningFolderPath))
        {
            mkdir $MiningFolderPath | Out-Null
        }

        $MineStructs=$db.MiningStructures
        foreach ($Mine in $MineStructs)
        {
            $xm = new-object System.Xml.XmlTextWriter("$MiningFolderPath\Mining Structure - $($Mine.Name).xmla",$encoding)
            $xm.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xm,$svr,$Mine,$true,$true) 
            $xm.Close() 

            # Write con
            Write-Output (" Mining Structure: {0}" -f $Mine.Name)
        }
        
        # 6) Roles
        $RolesFolderPath = "$SSASDBFolderPath\Roles"
        if(!(test-path -path $RolesFolderPath))
        {
            mkdir $RolesFolderPath | Out-Null
        }

        $Roles=$db.Roles
        foreach ($Role in $Roles)
        {

            $xr = new-object System.Xml.XmlTextWriter("$RolesFolderPath\Role - $($Role.Name).xmla",$encoding)
            $xr.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xr,$svr,$role,$true,$true) 
            $xr.Close() 

            # Write con
            Write-Output (" Role: {0}" -f $Role.Name)

        }


        # 7) Assemblies
        $AssemblyFolderPath = "$SSASDBFolderPath\Assemblies"
        if(!(test-path -path $AssemblyFolderPath))
        {
            mkdir $AssemblyFolderPath | Out-Null
        }

        $Assemblies=$db.Assemblies
        foreach ($Asm in $Assemblies)
        {
            $xa = new-object System.Xml.XmlTextWriter("$AssemblyFolderPath\Assembly - $($Asm.Name).xmla",$encoding)
            $xa.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xa,$svr,$Asm,$true,$true) 
            $xa.Close() 

            # Write con
            Write-Output (" Assembly: {0}" -f $Asm.Name)
        }


        # 8) Data Sources
        $DSFolderPath = "$SSASDBFolderPath\DataSources"
        if(!(test-path -path $DSFolderPath))
        {
            mkdir $DSFolderPath | Out-Null
        }

        $DataSources=$db.DataSources
        foreach ($DS in $DataSources)
        {
            $xds = new-object System.Xml.XmlTextWriter("$DSFolderPath\Data Source - $($DS.Name).xmla",$encoding)
            $xds.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xds,$svr,$DS,$true,$true) 
            $xds.Close() 

            # Write con
            Write-Output (" DataSource: {0}" -f $DS.Name)
        }

        # 9) Data Source Views
        $DSVFolderPath = "$SSASDBFolderPath\DataSourceViews"
        if(!(test-path -path $DSVFolderPath))
        {
            mkdir $DSVFolderPath | Out-Null
        }

        $DataSourceViews=$db.DataSourceViews
        foreach ($DSV in $DataSourceViews)
        {
            $xdsv = new-object System.Xml.XmlTextWriter("$DSVFolderPath\Data Source View - $($DSV.Name).xmla",$encoding)
            $xdsv.Formatting = [System.Xml.Formatting]::Indented 
            [Microsoft.AnalysisServices.Scripter]::WriteCreate($xdsv,$svr,$DSV,$true,$true) 
            $xdsv.Close() 

            # Write con
            Write-Output (" DataSourceView: {0}" -f $DSV.Name)
        }


    # End MD Scripting
    }


} 
$svr.Disconnect()

# --------------------
# SSAS Tabular Objects
# --------------------
Write-Output "`r`nScripting out SSAS Tabular Database Objects..."

# Write out rows
$RunTime = Get-date

# MD Server Properties
$Props=$Tsvr.ServerProperties    
$myoutputfile4 = $FullFolderPath+"\SSAS_Tabular_Engine_Settings.html"
$myHtml1 = $Props | sort-object Name | select Name, Value, CurrentValue, DefaultValue, RequiresRestart, Type, Units, Category | `
ConvertTo-Html -Fragment -as table -PreContent "<h1>Server: $SqlInstance</H1><H2>SSAS Tabular Engine Settings</h2>"
Convertto-Html -head $head -Body "$myHtml1" -Title "SSAS Tabular Engine Settings"  -PostContent "<h3>Ran on : $RunTime</h3>" | Set-Content -Path $myoutputfile4

Write-Output (" Server Tabular Engine Config Settings: {0}" -f $Props.count)


foreach ($tdb in $Tsvr.Databases) 
{         
    # Create SubFolder for each SSAS Database
    $SSASDBname = $tdb.Name
    $SSASDBFolderPath = $fullfolderPath+"$SSASDBname"
    if(!(test-path -path $SSASDBFolderPath))
    {
        mkdir $SSASDBFolderPath | Out-Null
    }

    # 0) Script Out Entire Database as XMLA
    $JsonFileName = $SSASDBFolderPath+"\Full Database - "+$tdb.Name+".json"
    $JsonFragment = [Microsoft.AnalysisServices.Tabular.JsonScripter]::GenerateSchema()
    $JsonFragment | Out-File -FilePath $JsonFileName -Force -Encoding default
    
    if ($tDb.ModelType -eq "Tabular")
    {

        # Write con
        Write-Output (" Database: [{0}]" -f $SSASDBname)
        
        # Get Database Model Reference
        $Model = $db.Model

        # 1) Connections
        $ConnFolderPath = "$SSASDBFolderPath\Connections"
        if(!(test-path -path $ConnFolderPath))
        {
            mkdir $ConnFolderPath | Out-Null
        }

        $Connections=$tdb.Model.DataSources
        foreach ($conn in $Connections)
        {
            # Cleanup funky Connection Names
            $ConnName = $($conn.name) -replace "/","_"
            $ConnName = $ConnName -replace ";","_"
            $ConnName = $ConnName -replace ",","_"

            $JsonFileName = $ConnFolderPath+"\"+$ConnName+".json"
            $JsonFragment = [Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreate($conn,$false)
            $JsonFragment | Out-File -FilePath $JsonFileName -Force -Encoding default

            # Write con
            Write-Output ("  Connection: {0}" -f $Conn.Name)
        }


        # 2) Tables
        $TabFolderPath = "$SSASDBFolderPath\Tables"
        if(!(test-path -path $TabFolderPath))
        {
            mkdir $TabFolderPath | Out-Null
        }

        $Tables=$tdb.Model.Tables
        foreach ($Table in $Tables)
        {
            $TableName = $Table.Name
            $JsonFileName = $TabFolderPath+"\"+$TableName+".json"
            $JsonFragment = [Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreate($table,$false)
            $JsonFragment | Out-File -FilePath $JsonFileName -Force -Encoding default

            # Write con
            Write-Output ("  Table: {0}" -f $TableName)

        }

        # 3) Roles
        $RoleFolderPath = "$SSASDBFolderPath\Roles"
        if(!(test-path -path $RoleFolderPath))
        {
            mkdir $RoleFolderPath | Out-Null
        }

        $Roles=$tdb.Model.Roles
        foreach ($Role in $Roles)
        {
            $RoleName = $Role.Name
            $JsonFileName = $RoleFolderPath+"\"+$RoleName+".json"
            $JsonFragment = [Microsoft.AnalysisServices.Tabular.JsonScripter]::ScriptCreate($Role,$false)
            $JsonFragment | Out-File -FilePath $JsonFileName -Force -Encoding default

            # Write con
            Write-Output ("  Role: {0}" -f $RoleName)

        }

    }
}

$Tsvr.Disconnect()


Write-Output ("Exported: {0} SSAS Databases" -f $svr.Databases.Count)

# Return To Base
set-location $BaseFolder

