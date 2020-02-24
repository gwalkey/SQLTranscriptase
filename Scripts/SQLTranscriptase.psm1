<#
.SYNOPSIS
    Provides Common functions for the action scripts
	
.DESCRIPTION
    Provides Common functions for the action scripts
	
.EXAMPLE
    
	
.Inputs

.Outputs
	
.NOTES
    1) Windows/SQL auth server connections

.LINK
	
#>

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
		$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=$Database;Integrated Security=SSPI;Application Name=SQLTranscriptase" 
		$Connection = New-Object System.Data.SqlClient.SqlConnection
		$Connection.ConnectionString = $SQLConnectionString
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $SQLExec
		$SqlCmd.Connection = $Connection
		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd
        $SqlCmd.CommandTimeout=0
    
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
		$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=$Database;User ID=$User;Password=$Password;Application Name=SQLTranscriptase" 
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

function GetSQLNumericalVersion
{
    [CmdletBinding()]
    Param([String]$myver)

    # Get Major Version Only
    [int]$ver = $myver.Substring(0,$myver.IndexOf('.'))

    switch ($ver)
    {
        7  {Write-Host "SQL Server 7"}
        8  {Write-Host "SQL Server 2000"}
        9  {Write-Host "SQL Server 2005"}
        10 {Write-Host "SQL Server 2008/R2"}
        11 {Write-Host "SQL Server 2012"}
        12 {Write-Host "SQL Server 2014"}
        13 {Write-Host "SQL Server 2016"}
        14 {Write-Host "SQL Server 2017"}
    	15 {Write-Host "SQL Server 2019"}
    }

    Write-Output $ver
}


export-modulemember -function ConnectWinAuth
export-modulemember -function ConnectSQLAuth
export-modulemember -function GetSQLNumericalVersion
