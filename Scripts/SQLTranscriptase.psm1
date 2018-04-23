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
		$SQLConnectionString = "Data Source=$SQLInstance;Initial Catalog=$Database;Integrated Security=SSPI;" 
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




export-modulemember -function ConnectWinAuth
export-modulemember -function ConnectSQLAuth
