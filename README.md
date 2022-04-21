# SQLTranscriptase 
<h2>Creating SQL Server Documentation using Powershell</h2>

These Powershell scripts allow both the beginning and experienced Powershell student and DBA both<br>
to learn Powershell and preserve SQL Server objects that comprise your On-Prem and Azure Servers.

They capture and export all SQL-Server related objects both inside and outside the database. As well as <br>
anything you cant access in SSMS by doing a "Right-click" Script-Out action.<br>

The Scripts are designed to be run separately or together. The default parameters run the scripts against [localhost].<br>
The Powershell script <b>00_RunAllScripts.ps1</b> runs most of the individual scripts in a pre-defined sequence to export<br>
most objects. But because the scripts are individual scripts, you are free to run or assemble them to your liking.<br>

The scripts use 3 MS Technologies to export their data:
1) TSQL
2) SMO - SQL Server Management Objects
3) WMI

They assume SysAdmin or equivalent permissions on the SQL Boxes you plan to script-out.

Please read the Wiki above for setup instructions as the scripts have MS dependencies that change frequently

<h3>Sample Execution</h3>

![alt text](https://raw.githubusercontent.com/gwalkey/SQLTranscriptase/master/SQLT.gif)

<h3>Agent Job Schedules Power BI Dashboard</h3>

![alt text](https://raw.githubusercontent.com/gwalkey/SQLTranscriptase/master/AgentJobsPBIX.jpg)

<h2>Requirements</h2>
Windows Powershell 5.1

<h2>Releases</h2>
https://github.com/gwalkey/SQLTranscriptase/releases

<h2>Setup Instructions</h2>
https://github.com/gwalkey/SQLTranscriptase/wiki/Setup-Instructions

<h2>Usage</h2>
https://github.com/gwalkey/SQLTranscriptase/wiki/Usage
  
<h2>Feedback</h2>
Open a GitHub Issue above

<h2>Project Background</h2>
<em>SQLTranscriptase</em> is a termed coined from Molecular Biology meaning the exporting of information from DNA
https://www.youtube.com/watch?v=aA-FcnLsF1g<br>
A need arose to both learn Powershell and document SQL Server that current SQL Tool Vendor's offerings could not meet.

<h2>Original Presentation</h2>
http://usergroup.tv/videos/scripting-out-sql-server-for-documentation-and-disaster-recovery
