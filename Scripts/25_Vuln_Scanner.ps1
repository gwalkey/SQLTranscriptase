<#
.SYNOPSIS
    Gets all MS Vulnerability Assessments from a Rules Database and runs them on another Server, outputting the results as Text and HTML files
	
.DESCRIPTION
    Gets all MS Vulnerability Assessments from a Rules Database and runs them on another Server, outputting the results as Text and HTML files
      
.EXAMPLE
    Run-VAScan.ps1 localhost
	
.EXAMPLE
    Run-VAScan.ps1 server01 sa password

.Inputs
    [ServerName\instance], [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    defaults to scanning localhost
    Needs Sysadmin=level security to run all checks

.LINK
    https://github.com/gwalkey
		
	
#>

Param(
  [string]$SQLInstance="localhost",
  [string]$myuser,
  [string]$mypass
)

# ----------------
# - Initializing 
# ----------------
Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Splash
Write-Host  -f Yellow -b Black "Start MS SQL Server Vulnerability Assessment"
Write-Output ("Server: {0} " -f $SQLInstance)


# Functions

function ConnectWinAuth
{   
    [CmdletBinding()]
    Param([String]$SQLExec,
          [String]$SQLInstance,
          [String]$Database)

    Process
    {
		# Open connection and Execute sql against server using Windows Auth
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=$Database;Integrated Security=SSPI;" 
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $SQLExec
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) |out-null
        if ($DataSet.Tables.Count -ne 0) 
        {
            $sqlresults = $DataSet.Tables[0]
        }
        else
        {
            $sqlresults =$null
        }

		# Close connection to sql server
		$Connection.Close()		    

        Write-Output $sqlresults
    }
}

function ConnectSQLAuth
{   
[CmdletBinding()]
    Param([String]$SQLExec,
          [String]$SQLInstance,
          [String]$Database,
          [String]$User,
          [String]$Password)

    Process
    {
		# Open connection and Execute sql against server using Windows Auth
		$DataSet = New-Object System.Data.DataSet
		$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=$Database;User ID=$User;Password=$Password" 
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $SQLExec
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
    
		# Insert results into Dataset table
		$SqlAdapter.Fill($DataSet) |out-null
        if ($DataSet.Tables.Count -ne 0) 
        {
            $sqlresults = $DataSet.Tables[0]
        }
        else
        {
            $sqlresults =$null
        }

		# Close connection to sql server
		$Connection.Close()		    

        Write-Output $sqlresults
    }
}


# --------
# Startup
# --------
# Server connection check
try
{
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
    {
        $results = ConnectSQLAuth "select serverproperty('productversion')" -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass        
        $serverauth="sql"
    }
    else
    {
        $results = ConnectWinAuth "select serverproperty('productversion')" -SQLInstance $SQLInstance -Database "master"
        $serverauth = "win"
    }

    if($results -ne $null)
    {
        Write-Output ("SQL Version: {0}" -f $results.Column1)
    }

}
catch
{
    Write-Output ("Error: {0}" -f $Error[0])
    Write-Host -f red "$SQLInstance appears offline"
    Set-Location $BaseFolder
	exit
}


# Fixup Server Names with Instances

# Create base output folder
$output_path = "$BaseFolder\$SQLInstance\MSVA\"
if(!(test-path -path $output_path))
{
    mkdir $output_path | Out-Null
}

$Now = (Get-Date -f "MM-dd-yyyy_HH_mm_ss")
$InstanceFileName = $SQLInstance.Replace('\','_')
$outputfile = $output_path+'MSVA_'+$InstanceFileName+'_'+$now+'_Remediations.txt'
$HTMLoutputfilebySev = $output_path+'MSVA_'+$InstanceFileName+'_'+$now+'_by_Severity.html'
$HTMLoutputfilebyDB = $output_path+'MSVA_'+$InstanceFileName+'_'+$now+'_by_Database.html'


$RulesDatabase = Import-Clixml -Path RulesDatabase.xml 
$VARulesHigh = $RulesDatabase | where-object {$_.Severity -eq 'High'}
$VARulesMed = $RulesDatabase | where-object {$_.Severity -eq 'Medium'}
$VARulesLow = $RulesDatabase | where-object {$_.Severity -eq 'Low'}

Write-Output("{0} Vulnerability Rules loaded" -f $RulesDatabase.Count)

# Get all online databases
$sql2 = 
"
SELECT
	*
FROM
	sys.databases
WHERE 
    [state]=0 and [name] not in ('tempdb','master','msdb','model','replication')
order by 
    [name]
"

$Database = $null
if ($serverauth -eq "win")
{
    $Databases = ConnectWinAuth $sql2 -SQLInstance $SQLInstance -Database "master"
}
else
{
    $Databases = ConnectSQLAuth $sql2 -SQLInstance $SQLInstance -Database "master" -User $myuser -Password $mypass
}

Write-Output("Databases found: {0}" -f @($databases).Count)

# HTML EMAIL data tables
# Fail Table
$EmailTable = New-Object system.Data.DataTable
$col1 = New-object system.Data.DataColumn Database,([string])
$col2 = New-Object system.Data.DataColumn Severity,([string])
$col3 = New-Object system.Data.DataColumn RuleId,([string])
$col4 = New-Object system.Data.DataColumn Title,([string])
$col5 = New-Object system.Data.DataColumn SortOrder,([string])
[Void]$EmailTable.columns.add($col1)
[Void]$EmailTable.columns.add($col2)
[Void]$EmailTable.columns.add($col3)
[Void]$EmailTable.columns.add($col4)
[Void]$EmailTable.columns.add($col5)

# Pass Table
$EmailTableOK = New-Object system.Data.DataTable 
$col1OK = New-object system.Data.DataColumn Database,([string])
$col2OK = New-Object system.Data.DataColumn Severity,([string])
$col3OK = New-Object system.Data.DataColumn RuleId,([string])
$col4OK = New-Object system.Data.DataColumn Title,([string])
$col5OK = New-Object system.Data.DataColumn SortOrder,([string])
[Void]$EmailTableOK.columns.add($col1OK)
[Void]$EmailTableOK.columns.add($col2OK)
[Void]$EmailTableOK.columns.add($col3OK)
[Void]$EmailTableOK.columns.add($col4OK)
[Void]$EmailTableOK.columns.add($col5OK)



# HTML Output file Table Formatting
$a =  "<h2>SQL Database Vulnerability Scan for [$SQLInstance]</h2>"
$a += "<h4><a target=_blank href='https://docs.microsoft.com/en-us/sql/relational-databases/security/security-center-for-sql-server-database-engine-and-azure-sql-database'>Using the MS SQL Security Center Database Rules</a></h4>"
$a += "<h4>Run at $(Get-Date)</h4>"
$a += "<style>"
$a += "TABLE{border-width:1px; border-style:solid; border-color:black;}"
$a += "TH{border-width:1px; padding:0px; border-style:solid; border-color:black; background-color:thistle}"
$a += "TD{border-width:1px; padding:0px; border-style:solid; border-color:black;}"
$a += "</style>"

# Test Failure Counts
[int]$HCount = 0
[int]$MCount = 0
[int]$LCount = 0
[int]$AllTests = 0

# Process Each Database
foreach($database in $Databases)
{
    $DBName = $Database.Name

    Write-Output("Database: {0}" -f $DBName)
    Write-Output("=========================")|  out-file $outputfile -Append -Encoding ascii
    Write-Output("Database: {0}" -f $DBName) |  out-file $outputfile -Append -Encoding ascii
    Write-Output("=========================")|  out-file $outputfile -Append -Encoding ascii

    # High Severity Vulns
    foreach($Rule1 in $VARulesHigh)
    {
        # Total = 54 Tests * Num databases
        $AllTests++

        # Recast DBNull as Powershell null for remed IF stmnt below
        if ($Rule1.ExpectedResult -eq [System.DBNull]::Value)
        {
            $ExpectedResult = $null
        }
        else
        {
            $ExpectedResult = $Rule1.ExpectedResult
        }

        # SQL
        $sql3=$Rule1.Query

        # Run This Rule on that database and get Pass/Fail
        if ($serverauth -eq "win")
        {
            try
            {
                $VAResults1 = ConnectWinAuth -SQLExec $sql3 -SQLInstance $SQLInstance -Database $DBName -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }
        else
        {
            try
            {
                $VAResults1 = ConnectSQLAuth -SQLExec $sql3 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }

        # Null result set = no violation
        if ($VAResults1 -eq $null)
        {
            $PFStatus1=" "            
        }
        else
        {
            # Does Violation Column Exist in the Result Set?
            if(Get-Member -inputobject $VAResults1 -name "Violation" -Membertype Properties)
            {
                # Trap Certain Test's Result Sets and reformat
                try
                {
                    if($VAResults1.Violation -eq 0 )
                    {
                        $PFStatus1=" "
                    }
                }
                catch
                {
                }

                try
                {
                    if($VAResults1.Violation -eq 1 )
                    {
                        $PFStatus1="Fail"
                        $HCount++
                    }
                }
                catch
                {
                }
            }
            else
            {
                # Write Fail and result set to log
                $PFStatus1="Fail"
                $HCount++
            }

        }

        # Add Results to DataTable for HTML Email Table
        if ($PFStatus1 -eq 'Fail')
        {
            $row = $EmailTable.NewRow()
            $row.Database = $DBName
	        $row.Severity = $Rule1. Severity
	        $row.RuleId = $Rule1.RuleID
	        $row.Title = $Rule1.Title
	        $row.SortOrder = 1
	        [Void]$EmailTable.Rows.Add($row)
        }
        else
        {
            $rowOK = $EmailTableOK.NewRow()
            $rowOK.Database = $DBName
	        $rowOK.Severity = $Rule1. Severity
	        $rowOK.RuleId = $Rule1.RuleID
	        $rowOK.Title = $Rule1.Title
	        $rowOK.SortOrder = 1
	        [Void]$EmailTableOK.Rows.Add($rowOK)
        }

        
        # Build Remediation Code
        if ($VAResults1 -ne $ExpectedResult)
        {

            [string]$strRemed=''

            # Process Violation 1/0 Items
            if (Get-Member -inputobject $VAResults1 -name "Violation" -Membertype Properties) 
            {
                # Rules that trigger with a Description-only remediation use the description
                if ($Rule1.RemedSkeleton.Substring(0,1) -eq '*' -and $VAResults1.Violation -eq 1) 
                {
                    $strRemed =   $Rule1.RemedSkeleton.Replace('*','')
                }
                else
                {
                    # Rule not violated - dont write a non-existent remediation to the log
                    if ($VAResults1.Violation -eq 0) {continue}

                    # Rule Violated - All of these use $1 to drop the Database name in
                    $strRemed =   $Rule1.RemedSkeleton.Replace('$1',$DBName)
                }                                               
            }
            else
            {
                # the resultset has rows, build remediation code using the skeleton and string substitution
                # Skip if the resultset has rows, but there is NO remediation skeleton, just 'Advice'
                if ($Rule1.RemedSkeleton.Substring(0,1) -eq '*')
                {
                    $strRemed =   $Rule1.RemedSkeleton.Replace('*','')
                }
                else
                {
                    foreach($Line in $VAResults1)
                    {
                        $RemedStringTemp= $Rule1.RemedSkeleton
                        For ($i=0; $i -lt $Line.ItemArray.Count; $i++) 
                        {
                            $reptarget = '$'+[string]$i
                            $RemedStringTemp= $RemedStringTemp.Replace($reptarget,$Line.ItemArray[$i]) 
                        }
                    
                        $strRemed +=$RemedStringTemp + " `r`n"
                    }
                }
            }

            # Log Remed Code
            Write-Output("{0}, {1}, {2}" -f $Rule1. Severity, $Rule1.RuleID, $Rule1.Title)
            Write-Output("{0}, {1}, {2}" -f $Rule1. Severity, $Rule1.RuleID, $Rule1.Title) | out-file $outputfile -Append -Encoding ascii
            Write-Output("{0}`r`n" -f $strRemed)
            Write-Output("{0}`r`n" -f $strRemed) | out-file $outputfile -Append -Encoding ascii
        }

    }

    # Medium Severity Vulns
    foreach($Rule2 in $VARulesMed)
    {
        
        # Total = 54 Tests * Num databases
        $AllTests++

        # Recast DBNull as Powershell null for remed IF stmnt below
        if ($Rule2.ExpectedResult -eq [System.DBNull]::Value)
        {
            $ExpectedResult = $null
        }
        else
        {
            $ExpectedResult = $Rule2.ExpectedResult
        }

        # SQL
        $sql4=$Rule2.Query

        # Run This Rule on that database
        if ($serverauth -eq "win")
        {
            try
            {
                $VAResults2 = ConnectWinAuth -SQLExec $sql4 -SQLInstance $SQLInstance -Database $DBName -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }
        else
        {
            try
            {
                $VAResults2 = ConnectSQLAuth -SQLExec $sql4 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass  -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }

        # Null result set = no violation
        if ($VAResults2 -eq $null)
        {
            $PFStatus2=" "  
        }
        else
        {
            # Does Violation Column Exist in in the Result Set?
            if(Get-Member -inputobject $VAResults2 -name "Violation" -Membertype Properties)
            {

                # Trap Certain Test's Result Sets and reformat
                try
                {
                    if($VAResults2.Violation -eq 0 )
                    {
                        $PFStatus2=" "

                    }
                }
                catch
                {
                }

                try
                {
                    if($VAResults2.Violation -eq 1 )
                    {
                        $PFStatus2="Fail"
                        $MCount++
                    }
                }
                catch
                {
                }
            }
            else
            {
                # Write Fail and result set to log
                $PFStatus2="Fail"
                $MCount++
            }

        }

        # Add Results to DataTable for HTML Email Table
        if ($PFStatus2 -eq 'Fail')
        {
            $row = $EmailTable.NewRow()
            $row.Database = $DBName
	        $row.Severity = $Rule2. Severity
	        $row.RuleId = $Rule2.RuleID
	        $row.Title = $Rule2.Title
	        $row.SortOrder = 2
	        [Void]$EmailTable.Rows.Add($row)
        }
        else
        {
            $rowOK = $EmailTableOK.NewRow()
            $rowOK.Database = $DBName
	        $rowOK.Severity = $Rule2. Severity
	        $rowOK.RuleId = $Rule2.RuleID
	        $rowOK.Title = $Rule2.Title
	        $rowOK.SortOrder = 2
	        [Void]$EmailTableOK.Rows.Add($rowOK)
        }

        # Build Remediation Code
        if ($VAResults2 -ne $ExpectedResult)
        {

            [string]$strRemed=''

            # Process Results Sets with Violation 1/0 
            if (Get-Member -inputobject $VAResults2 -name "Violation" -Membertype Properties) 
            {
                # Rules that trigger with a Description-only remediation use the description
                if ($Rule2.RemedSkeleton.Substring(0,1) -eq '*' -and $VAResults2.Violation -eq 1) 
                {
                    $strRemed =   $Rule2.RemedSkeleton.Replace('*','')
                }
                else
                {
                    # Rule not violated - dont write a non-existent remediation to the log
                    if ($VAResults2.Violation -eq 0) {continue}

                    # Rule Violated - All of these use $1 to drop the Database name in
                    $strRemed =   $Rule2.RemedSkeleton.Replace('$1',$DBName)
                }               
            }
            else
            {
                # the resultset has rows, build remediation code using the skeleton and string substitution
                # Skip if the resultset has rows, but there is NO remediation skeleton, just 'Advice'
                if ($Rule2.RemedSkeleton.Substring(0,1) -eq '*')
                {
                    $strRemed =   $Rule2.RemedSkeleton.Replace('*','')
                }
                else
                {
                    foreach($Line in $VAResults2)
                    {
                        $RemedStringTemp= $Rule2.RemedSkeleton
                        For ($i=0; $i -lt $Line.ItemArray.Count; $i++) 
                        {
                            $reptarget = '$'+[string]$i
                            $RemedStringTemp= $RemedStringTemp.Replace($reptarget,$Line.ItemArray[$i]) 
                        }
                        
                        $strRemed +=$RemedStringTemp + " `r`n"
                    }
                }
            }

            # Log Remed Code
            Write-Output("{0}, {1}, {2}" -f $Rule2. Severity, $Rule2.RuleID, $Rule2.Title)
            Write-Output("{0}, {1}, {2}" -f $Rule2. Severity, $Rule2.RuleID, $Rule2.Title) | out-file $outputfile -Append -Encoding ascii
            Write-Output("{0}`r`n" -f $strRemed)
            Write-Output("{0}`r`n" -f $strRemed) | out-file $outputfile -Append -Encoding ascii
        }


    }

    # Low Severity Vulns
    foreach($Rule3 in $VARulesLow)
    {

        # Total = 54 Tests * Num databases
        $AllTests++

        # Recast DBNull as Powershell null for remed IF stmnt below
        if ($Rule3.ExpectedResult -eq [System.DBNull]::Value)
        {
            $ExpectedResult = $null
        }
        else
        {
            $ExpectedResult = $Rule3.ExpectedResult
        }

        # SQL
        $sql5=$Rule3.Query

        # Run This Rule on that database
        if ($serverauth -eq "win")
        {
            Try
            {
                $VAResults3 = ConnectWinAuth -SQLExec $sql5 -SQLInstance $SQLInstance -Database $DBName -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }
        else
        {
            try
            {
                $VAResults3 = ConnectSQLAuth -SQLExec $sql5 -SQLInstance $SQLInstance -Database $DBName -User $myuser -Password $mypass -ErrorAction Stop
            }
            catch
            {
                continue
            }
        }

        # Null result set = no violation
        if ($VAResults3 -eq $null)
        {
            $PFStatus3=" "  
        }
        else
        {
            # Does Violation Column Exist in in the Result Set?
            if(Get-Member -inputobject $VAResults3 -name "Violation" -Membertype Properties)
            {
                # Trap Certain Test's Result Sets and reformat
                try
                {
                    if($VAResults3.Violation -eq 0 )
                    {
                        $PFStatus3=" "
                    }
                }
                catch
                {
                }

                try
                {
                    if($VAResults3.Violation -eq 1 )
                    {
                        $PFStatus3="Fail"
                        $LCount++
                    }
                }
                catch
                {
                }
            }
            else
            {
                # Write Fail and result set to log
                $PFStatus3="Fail"
                $LCount++
            }

        }

        # Add Results to DataTable for HTML Email Table
        if ($PFStatus3 -eq 'Fail')
        {
            $row = $EmailTable.NewRow()
            $row.Database = $DBName
	        $row.Severity = $Rule3. Severity
	        $row.RuleId = $Rule3.RuleID
	        $row.Title = $Rule3.Title
	        $row.SortOrder = 3
	        [Void]$EmailTable.Rows.Add($row)
        }
        else
        {
            $rowOK = $EmailTableOK.NewRow()
            $rowOK.Database = $DBName
	        $rowOK.Severity = $Rule3. Severity
	        $rowOK.RuleId = $Rule3.RuleID
	        $rowOK.Title = $Rule3.Title
	        $rowOK.SortOrder = 3
	        [Void]$EmailTableOK.Rows.Add($rowOK)
        }

        # Build Remediation Code
        if ($VAResults3 -ne $ExpectedResult)
        {

            [string]$strRemed=''

            # Process Results Sets with Violation 1/0 
            if (Get-Member -inputobject $VAResults3 -name "Violation" -Membertype Properties) 
            {
                # Rules that trigger with a Description-only remediation use the description
                if ($Rule3.RemedSkeleton.Substring(0,1) -eq '*' -and $VAResults3.Violation -eq 1) 
                {
                    $strRemed =   $Rule3.RemedSkeleton.Replace('*','')
                }
                else
                {
                    # Rule not violated - dont write a non-existent remediation to the log
                    if ($VAResults3.Violation -eq 0) {continue}

                    # Rule Violated - All of these use $1 to drop the Database name in
                    $strRemed =   $Rule3.RemedSkeleton.Replace('$1',$DBName)
                }               
            }
            else
            {
                # the resultset has rows, build remediation code using the skeleton and string substitution
                # Skip if the resultset has rows, but there is NO remediation skeleton, just 'Advice'
                if ($Rule3.RemedSkeleton.Substring(0,1) -eq '*')
                {
                    $strRemed =   $Rule3.RemedSkeleton.Replace('*','')
                }
                else
                {
                    foreach($Line in $VAResults3)
                    {
                        $RemedStringTemp= $Rule3.RemedSkeleton
                        For ($i=0; $i -lt $Line.ItemArray.Count; $i++) 
                        {
                            $reptarget = '$'+[string]$i
                            $RemedStringTemp= $RemedStringTemp.Replace($reptarget,$Line.ItemArray[$i]) 
                        }
                        
                        $strRemed +=$RemedStringTemp + " `r`n"
                    }
                }
            }

            # Log Remed Code
            Write-Output("{0}, {1}, {2}" -f $Rule3. Severity, $Rule3.RuleID, $Rule3.Title)
            Write-Output("{0}, {1}, {2}" -f $Rule3. Severity, $Rule3.RuleID, $Rule3.Title) | out-file $outputfile -Append -Encoding ascii
            Write-Output("{0}`r`n" -f $strRemed)
            Write-Output("{0}`r`n" -f $strRemed) | out-file $outputfile -Append -Encoding ascii
        }

    }
    
    
    Write-Output("`r`n")
    Write-Output("`r`n") | out-file $outputfile -Append -Encoding ascii

}

# Calc BarChart relative lengths
$HBar =$HCount*10+10
$HBar = [string]$HBar+'px'

$MBar =$MCount*10+10
$MBar = [string]$MBar+'px'

$LBar =$LCount*10+10
$LBar = [string]$LBar+'px'

# Table Decorations
$TotalFails = $HCount+$MCount+$LCount
$TotalPasses = $AllTests - $TotalFails
$TotalDatabases = @($Databases).Count
$TotalRules = $VARulesHigh.Count + $VARulesMed.count + $VARulesLow.Count

# Export DT Rows as HTML Table
$Pre = 
@"
<style>

.red div {
  font: 10px sans-serif;
  background-color: red;
  text-align: right;
  padding: 3px;
  margin: 1px;
  color: white;
}

.steel div {
  font: 10px sans-serif;
  background-color: steelblue;
  text-align: right;
  padding: 3px;
  margin: 1px;
  color: white;
}

.green div {
  font: 10px sans-serif;
  background-color: DarkGreen;
  text-align: right;
  padding: 3px;
  margin: 1px;
  color: white;
}
</style>

<h2>Vulnerability Summary:</h2>

<style>
.normal TABLE{
    border-width:1px; 
    border-style:solid; 
    border-color:black;
    }
.normal TH{
    border-width:1px; 
    padding:0px; 
    border-style:solid; 
    border-color:black;
    }
</style>

<table class="normal">
<tr><th style="background-color:transparent;">Risk</th><th style="background-color:transparent;">Count</th></tr>
<tr><td>High</td><td><div class="red"><div style="width: $HBar;">$HCount</div></div></td></tr>
<tr><td>Medium</td><td><div class="steel"><div style="width: $MBar;">$MCount</div></div></td></tr>
<tr><td>Low</td><td><div class="green"><div style="width: $LBar;">$LCount</div></div></td></tr>
</table>

<h2>Scan Summary:</h2>
<h4>Total Databases: $TotalDatabases </h4>
<h4>Total Rules: $TotalRules </h4>
<h4>Total Tests: $AllTests</h4>

<h2>Scan Details:</h2>
<h3>Failed ($TotalFails)</h3>
"@

# ------------------
# Sorted by Severity
# ------------------
# Fail Table First
$Failbody = $EmailTable | sort-object -property SortOrder, Database, RuleId | ConvertTo-Html -as Table -Property Database, Severity, RuleId, Title -Title "Fail Results" -Head $a  -PreContent $Pre | Out-String
$Failbody | out-file $HTMLoutputfilebySev -Append -encoding ascii

"<h3>Passed ($TotalPasses)</h3>" | out-file $HTMLoutputfilebySev -Append -encoding ascii

# Pass Table Second
$Failbody = $EmailTableOK | sort-object -property SortOrder, Database, RuleId | ConvertTo-Html -as Table -Property Database, Severity, RuleId, Title -Title "Pass Results"| Out-String
$Failbody | out-file $HTMLoutputfilebySev -Append -encoding ascii

# -------------------
# Sorted by Database
# -------------------
# Fail Table First
$Failbody = $EmailTable | sort-object -property Database, SortOrder, RuleId | ConvertTo-Html -as Table -Property Database, Severity, RuleId, Title -Title "Fail Results" -Head $a  -PreContent $Pre | Out-String
$Failbody | out-file $HTMLoutputfilebyDB -Append -encoding ascii

"<h3>Passed ($TotalPasses)</h3>" | out-file $HTMLoutputfilebyDB -Append -encoding ascii

# Pass Table Second
$Failbody = $EmailTableOK | sort-object -property Database, SortOrder, RuleId | ConvertTo-Html -as Table -Property Database, Severity, RuleId, Title -Title "Pass Results"| Out-String
$Failbody | out-file $HTMLoutputfilebyDB -Append -encoding ascii
