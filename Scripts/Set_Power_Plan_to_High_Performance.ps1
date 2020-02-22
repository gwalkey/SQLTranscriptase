<#
.SYNOPSIS
    Sets the Windows Power Plan to High Performance (default is Balanced)
	
.DESCRIPTION
   Uses powercfg.exe
   
.EXAMPLE
    Set_Power_Plan_to_High_Performance.ps1 c0sqltier1
	

.Inputs
    ServerName

.Outputs
    Power Plan Changed to High Performance Profile
	
.NOTES


.LINK

	https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/solutions/sql-server-on-vmware-best-practices-guide.pdf
    
    https://www.codykonior.com/2016/10/20/i-like-you-but-i-dont-like-your-best-practice-power-plans/

    https://www.reddit.com/r/vmware/comments/1ycf27/windows_guest_os_power_policy/cfj9wwl/

	
#>

cls

powercfg /list

Write-Host -f Yellow -b Black "`r`nSetting Power Plan to High Performance"

powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

powercfg /list

