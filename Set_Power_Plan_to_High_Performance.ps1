<#
.SYNOPSIS
    Sets the Windows Power Plan to High Performance (default is Balanced)
	
.DESCRIPTION
   Uses CIM
   
.EXAMPLE
    Set_Power_Plan_to_High_Performance.ps1 c0sqltier1
	

.Inputs
    ServerName

.Outputs
    Power Plan Changed to High Performance
	
.NOTES

    Windows 2003 Doesnt have the WMI/CIM bits in place for power management	

.LINK

	https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/solutions/sql-server-on-vmware-best-practices-guide.pdf
    
    https://www.codykonior.com/2016/10/20/i-like-you-but-i-dont-like-your-best-practice-power-plans/

    https://www.reddit.com/r/vmware/comments/1ycf27/windows_guest_os_power_policy/cfj9wwl/

	
#>
Param(
  [string]$WinServer
)

if ($WinServer -eq $null)
{
    exit
}

$p = Get-CimInstance -computername $WinServer -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High Performance'" | Out-Null

Invoke-CimMethod -InputObject $p -MethodName Activate

