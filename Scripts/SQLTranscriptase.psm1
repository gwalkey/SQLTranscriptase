<#
.SYNOPSIS
    Provides Common functions for the action scripts
	
.DESCRIPTION
    Provides Common functions for the action scripts
	
.EXAMPLE
	
.Inputs

.Outputs
	
.NOTES
    1) Windows/SQL auth server connection Code
    2) Gets Major SQL Version
    3) Loads latest installed version of SQL SMO
    4) Loads latest installed version of DacFX Framework

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

function LoadSQLSMO
{

    # Try NuGet Package Version
    try
    {
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Smo.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.SmoExtended.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.XEvent.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.XEventEnum.dll" -ErrorAction Stop
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.SqlManagementObjects.150.18208.0\lib\net45\Microsoft.SqlServer.Management.Sdk.Sfc.dll" -ErrorAction Stop
        Write-Output "Using SMO Library [vNext] (150.18208.0)"
        return
    }
    catch
    {
    }
     
    # 2019
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=15.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v15 (2019)"
        return
    }
    catch
    {
    }
	
    # 2017
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v14 (2017)"
        return
    }
    catch
    {
    }

    # 2016
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v13 (2016)"
        return
    }
    catch
    {
    }

    # 2014
    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v12 (2014)"
        return
    }
    catch
    {
    }

    # 2012
    try 
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEvent, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.XEventEnum, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library v11 (2012)"
        return
    }
    catch
    {
    }

    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Write-Output "Using SMO Library 10 (2008)"
    }
    catch
    {
    }

    try
    {
        Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=9.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop
        #Write-Output "Using SMO Library 9 (2005)"
    }
    catch
    {
    }

    Write-output "No SMO Libraries found on your Machine. Please load the latest version of SMO and try again"
    return

}


function LoadDacFX
{

    # NuGet
    try
    {
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\Microsoft.SqlServer.DacFx.x86.150.4573.2\lib\net46\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac NuGet 150.4573.2')
        return
    }
    catch
    {
    }

    # 2019
    try
    {
        Add-Type -Path "C:\Program Files\Microsoft SQL Server\150\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2019')
        return
    }
    catch
    {
    }

    # 2017
    try
    {    
        Add-Type -Path "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2017')
        return
    }
    catch
    {
    }

    # 2016
    try
    {
        Add-Type -Path "C:\Program Files (x86)\Microsoft SQL Server\130\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2016')
        return
    }
    catch
    {
    }

    # 2014 try
    {    
        Add-Type -Path "C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2014')
        return
    }
    catch
    {
    }

    # 2012
    try
    {
        add-type -path "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2012')
        return
    }
    catch
    {
    }

    # 2008
    try
    {
        Add-Type -Path "C:\Program Files (x86)\Microsoft SQL Server\100\DAC\bin\Microsoft.SqlServer.Dac.dll" -ErrorAction Stop
        Write-Output('Using Dac v2008')
        return
    }
    catch
    {
    }

    Write-Output "Microsoft.SqlServer.Dac.dll not found, exiting"
    exit
}


export-modulemember -function ConnectWinAuth
export-modulemember -function ConnectSQLAuth
export-modulemember -function GetSQLNumericalVersion
export-modulemember -function LoadDacFX
export-modulemember -function LoadSQLSMO