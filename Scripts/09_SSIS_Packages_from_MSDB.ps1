<#
.SYNOPSIS
    Gets the SQL Server Integration Services packages stored in MSDB on the target server
	
.DESCRIPTION
   Writes the SSIS Packages out to the "09 - SSIS_MSDB" folder
   
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 localhost
	
.EXAMPLE
    09_SSIS_Packages_from_MSDB.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
	Might have to run this Elevated (As Administrator) on Windows 8+
	
.LINK


#>

Param(
  [string]$SQLInstance='localhost',
  [string]$myuser,
  [string]$mypass
)

Set-StrictMode -Version latest;

[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


#  Script Name
Write-Host  -f Yellow -b Black "09 - SSIS Packages from MSDB"

# Load SMO Assemblies
Import-Module ".\LoadSQLSmo.psm1"
LoadSQLSMO


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./09_SSIS_Packages_from_MSDB.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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
        $myver = $results.Column1

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
        $myver = $results.Column1

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



# Create output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\09 - SSIS_MSDB"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }


# SSIS 2005
if ($myver -like "9.0*")
{

    Write-Output "SSIS is 2005"

    $Packages = @()
    $sql1 = "
    with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysdtspackagefolders90 PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysdtspackagefolders90 CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysdtspackages90 P on P.folderid = F.folderid
        WHERE F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

    # SQL Auth
    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
        {
        Write-Output "Using SQL Auth"

        
        # .NET Method
	    # Open connection and Execute sql against server
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $sql1
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
    	# Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null

        # Close connection to sql server
	    $Connection.Close()
	    $Packages += $DataSet.Tables[0].Rows
        

        #$Packages += Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $sql1         
    }
    else
    {
        Write-Output "Using Windows Auth"
        
        
      	# .NET Method
	    # Open connection and Execute sql against server using Windows Auth
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $sql1
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null

	    # Close connection to sql server
	    $Connection.Close()
	    $Packages += $DataSet.Tables[0].Rows
        

        #$Packages += Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $sql1
    }

    #Save
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
    }
}

# SSIS 2008 +
else
{
    Write-Output "SSIS is 2008+"
	
    $Packages = @()
    $sql2 = "
        with ChildFolders
        as
        (
            select PARENT.parentfolderid, PARENT.folderid, PARENT.foldername,
                cast('' as sysname) as RootFolder,
                cast(PARENT.foldername as varchar(max)) as FullPath,
                0 as Lvl
            from msdb.dbo.sysssispackagefolders PARENT
            where PARENT.parentfolderid is null
            UNION ALL
            select CHILD.parentfolderid, CHILD.folderid, CHILD.foldername,
                case ChildFolders.Lvl
                    when 0 then CHILD.foldername
                    else ChildFolders.RootFolder
                end as RootFolder,
                cast(ChildFolders.FullPath + '/' + CHILD.foldername as varchar(max))
                    as FullPath,
                ChildFolders.Lvl + 1 as Lvl
            from msdb.dbo.sysssispackagefolders CHILD
                inner join ChildFolders on ChildFolders.folderid = CHILD.parentfolderid
        )
        select F.RootFolder, F.FullPath, P.name as PackageName,
            P.description as PackageDescription, P.packageformat, P.packagetype,
            P.vermajor, P.verminor, P.verbuild, P.vercomments,
            cast(cast(P.packagedata as varbinary(max)) as xml) as Pkg
        from ChildFolders F
            inner join msdb.dbo.sysssispackages P on P.folderid = F.folderid
        WHERE    F.RootFolder NOT LIKE 'Data Collector%'    
        order by F.FullPath asc, P.name asc;
        "

    if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
        {
        Write-Output "Using SQL Auth"

        
        # .NET Method
	    # Open connection and Execute sql against server
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;User ID=$myuser;Password=$mypass;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $sql2
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
    	# Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null

        # Close connection to sql server
	    $Connection.Close()
	    $Packages += $DataSet.Tables[0].Rows
        

        $Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Username $myuser -Password $mypass -Query $sql2

    }
    else
    {
        Write-Output "Using Windows Auth"

        
        # .NET Method
	    # Open connection and Execute sql against server using Windows Auth
	    $DataSet = New-Object System.Data.DataSet
	    $SQLConnectionString = "Data Source=$SQLInstance;Integrated Security=SSPI;"
	    $Connection = New-Object System.Data.SqlClient.SqlConnection
	    $Connection.ConnectionString = $SQLConnectionString
	    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	    $SqlCmd.CommandText = $sql2
	    $SqlCmd.Connection = $Connection
	    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	    $SqlAdapter.SelectCommand = $SqlCmd
    
	    # Insert results into Dataset table
	    $SqlAdapter.Fill($DataSet) | out-null

	    # Close connection to sql server
	    $Connection.Close()
	    $Packages += $DataSet.Tables[0].Rows
        

        #$Packages +=  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query $sql2
        
    }


    #Save
    Foreach ($pkg in $Packages)
    {
    
        $pkgName = $Pkg.packagename
        $folderPath = $Pkg.rootfolder
        $fullfolderPath = "$BaseFolder\$SQLInstance\09 - SSIS_MSDB\$folderPath\"
        if(!(test-path -path $fullfolderPath))
        {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"

        $Pkg.packagename
    }


    Write-Output ("{0} SSIS MSDB Packages Exported" -f $packages.count)
}

set-location $BaseFolder

