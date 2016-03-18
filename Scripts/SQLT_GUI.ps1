<#
.SYNOPSIS
    Runs all or selected Scripts based on chosen checkboxes

	
.DESCRIPTION

	
.EXAMPLE
    SQLT_GUI.ps1

	
.Inputs


.Outputs

	
.NOTES

	
.LINK
	https://github.com/gwalkey
	
#>


[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") |out-null
[reflection.assembly]::LoadwithPartialName("System.Drawing") | Out-Null


[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName


# Create the form
$form = New-Object Windows.Forms.Form
$form.Name = "SQLTranscriptase"
$form.text = "SQLTranscriptase - SQL Server Documentation in Powershell"
$form.Size = New-Object Drawing.Size @(500,680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.AutoSize = $false
$Form.MaximizeBox = $False
$Form.WindowState = "Normal"
$Form.SizeGripStyle = "Hide"
$Form.ShowInTaskbar = $True
$Form.BackColor = "Silver"

# Add the Logo
$file = (get-item ".\Media\SQLT.jpg")
$img = [System.Drawing.Image]::Fromfile($file);
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Width =  494
$pictureBox.Height = 61
$pictureBox.Location = New-Object Drawing.Point(1,1)
$pictureBox.Image = $img;

# Add the ICON
$Icon = New-Object system.drawing.icon (".\Media\Script.ICO")
$Form.Icon = $Icon
 

# Server
# Label
$label1 = New-Object Windows.Forms.Label
$label1.Location = New-Object Drawing.Point 20,65
$label1.Size = New-Object Drawing.Point 200,15
$label1.text = "SQL Server\Instance and Credentials"

# Username
# TextBox
$myServerText = New-Object Windows.Forms.TextBox
$myServerText.Location = New-Object Drawing.Point 20,80
$myServerText.Size = New-Object Drawing.Point 200,30
$myServerText.Text = "localhost"
$myServerText.TabIndex = 0

# label
$label2 = New-Object Windows.Forms.Label
$label2.Location = New-Object Drawing.Point 5,83
$label2.Size = New-Object Drawing.Point 12,12
$label2.text = "S"

# Username
# TextBox
$myUserText = New-Object Windows.Forms.TextBox
$myUserText.Location = New-Object Drawing.Point 20,100
$myUserText.Size = New-Object Drawing.Point 200,30
$myUserText.Text = ""
$myUserText.TabIndex = 2

# Label
$label3 = New-Object Windows.Forms.Label
$label3.Location = New-Object Drawing.Point 5,103
$label3.Size = New-Object Drawing.Point 12,12
$label3.text = "U"

# Password
# Create TextBox and set text, size and location
$myPassText = New-Object Windows.Forms.TextBox
$myPassText.Location = New-Object Drawing.Point 20,120
$myPassText.Size = New-Object Drawing.Point 200,30
$myPassText.Text = ""
$myPassText.TabIndex = 3

# Create the label control and set text, size and location
$label4 = New-Object Windows.Forms.Label
$label4.Location = New-Object Drawing.Point 5,123
$label4.Size = New-Object Drawing.Point 12,12
$label4.text = "P"


# Create GO button
$GoButton = New-Object System.Windows.Forms.Button
$GoButton.Location = New-Object System.Drawing.Size(85,590)
$GoButton.Size = New-Object System.Drawing.Size(100,40)
$GoButton.Text = "GO"
$GoButton.Add_Click({
    $Form.Close()
})


# Create Cancel button
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(275,590)
$CancelButton.Size = New-Object System.Drawing.Size(100,40)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({
    [System.Environment]::Exit(0)
})


# Checkboxes
# -- All Scripts
$cb_AllScripts = New-Object System.Windows.Forms.CheckBox
$cb_AllScripts.AutoSize = $True
$cb_AllScripts.Location = New-Object System.Drawing.Point(20, 145)
$cb_AllScripts.Name = "cb_AllTools"
$cb_AllScripts.TabIndex = 4
$cb_AllScripts.Text = "All Scripts"
$myFont = New-Object System.Drawing.Font("Times New Roman",10,[System.Drawing.FontStyle]::Bold)
$cb_AllScripts.Font = $myFont
$cb_AllScripts.Checked = $true
$cb_AllScripts.Add_CheckStateChanged({
    if ($cb_AllScripts.Checked) {
        $checkbox1.Checked = $false
        $checkbox2.Checked = $false
        $checkbox3.Checked = $false
        $checkbox4.Checked = $false
        $checkbox5.Checked = $false
        $checkbox6.Checked = $false
        $checkbox7.Checked = $false
        $checkbox8.Checked = $false
        $checkbox9.Checked = $false
        $checkbox10.Checked = $false
        $checkbox11.Checked = $false
        $checkbox12.Checked = $false
        $checkbox13.Checked = $false
        $checkbox14.Checked = $false
        $checkbox15.Checked = $false
        $checkbox16.Checked = $false
        $checkbox17.Checked = $false
        $checkbox18.Checked = $false
        $checkbox19.Checked = $false
        $checkbox20.Checked = $false
        $checkbox21.Checked = $false
        $checkbox22.Checked = $false
        $checkbox23.Checked = $false
        $checkbox24.Checked = $false
        $checkbox25.Checked = $false
        $checkbox26.Checked = $false
        $checkbox27.Checked = $false
        $checkbox28.Checked = $false
        $checkbox29.Checked = $false
        $checkbox30.Checked = $false
        $checkbox31.Checked = $false
        $checkbox32.Checked = $false
        $checkbox33.Checked = $false
        $checkbox34.Checked = $false
        $checkbox35.Checked = $false
        $checkbox36.Checked = $false
        $checkbox37.Checked = $false
        $checkbox38.Checked = $false
        $checkbox39.Checked = $false
        $checkbox40.Checked = $false
        $checkbox41.Checked = $false
        $checkbox42.Checked = $false
        $checkbox43.Checked = $false
    }
})


$checkbox1 = New-Object System.Windows.Forms.CheckBox
$checkbox1.AutoSize = $True
$checkbox1.Location = New-Object System.Drawing.Point(20, 165)
$checkbox1.Name = "checkbox1"
$checkbox1.TabIndex = 5
$checkbox1.Text = "01_Server_Applicance"
$checkbox1.Add_CheckStateChanged({
    if ($checkbox1.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox2 = New-Object System.Windows.Forms.CheckBox
$checkbox2.AutoSize = $True
$checkbox2.Location = New-Object System.Drawing.Point(20, 180)
$checkbox2.Name = "checkbox2"
$checkbox2.TabIndex = 6
$checkbox2.Text = "01_Server_Credentials"
$checkbox2.Add_CheckStateChanged({
    if ($checkbox2.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox3 = New-Object System.Windows.Forms.CheckBox
$checkbox3.AutoSize = $True
$checkbox3.Location = New-Object System.Drawing.Point(20, 195)
$checkbox3.Name = "checkbox3"
$checkbox3.TabIndex = 7
$checkbox3.Text = "01_Server_Logins"
$checkbox3.Add_CheckStateChanged({
    if ($checkbox3.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox4 = New-Object System.Windows.Forms.CheckBox
$checkbox4.AutoSize = $True
$checkbox4.Location = New-Object System.Drawing.Point(20, 210)
$checkbox4.Name = "checkbox4"
$checkbox4.TabIndex = 8
$checkbox4.Text = "01_Server_Resource_Governor"
$checkbox4.Add_CheckStateChanged({
    if ($checkbox4.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox5 = New-Object System.Windows.Forms.CheckBox
$checkbox5.AutoSize = $True
$checkbox5.Location = New-Object System.Drawing.Point(20, 225)
$checkbox5.Name = "checkbox5"
$checkbox5.TabIndex = 9
$checkbox5.Text = "01_Server_Roles"
$checkbox5.Add_CheckStateChanged({
    if ($checkbox5.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox6 = New-Object System.Windows.Forms.CheckBox
$checkbox6.AutoSize = $True
$checkbox6.Location = New-Object System.Drawing.Point(20, 240)
$checkbox6.Name = "checkbox6"
$checkbox6.TabIndex = 10
$checkbox6.Text = "01_Server_Settings"
$checkbox6.Add_CheckStateChanged({
    if ($checkbox6.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox7 = New-Object System.Windows.Forms.CheckBox
$checkbox7.AutoSize = $True
$checkbox7.Location = New-Object System.Drawing.Point(20, 255)
$checkbox7.Name = "checkbox7"
$checkbox7.TabIndex = 11
$checkbox7.Text = "01_Server_Shares"
$checkbox7.Add_CheckStateChanged({
    if ($checkbox7.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox8 = New-Object System.Windows.Forms.CheckBox
$checkbox8.AutoSize = $True
$checkbox8.Location = New-Object System.Drawing.Point(20, 270)
$checkbox8.Name = "checkbox8"
$checkbox8.TabIndex = 12
$checkbox8.Text = "01_Server_Startup_Procs"
$checkbox8.Add_CheckStateChanged({
    if ($checkbox8.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox9 = New-Object System.Windows.Forms.CheckBox
$checkbox9.AutoSize = $True
$checkbox9.Location = New-Object System.Drawing.Point(20, 285)
$checkbox9.Name = "checkbox9"
$checkbox9.TabIndex = 13
$checkbox9.Text = "01_Server_Storage"
$checkbox9.Add_CheckStateChanged({
    if ($checkbox9.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox10 = New-Object System.Windows.Forms.CheckBox
$checkbox10.AutoSize = $True
$checkbox10.Location = New-Object System.Drawing.Point(20, 300)
$checkbox10.Name = "checkbox10"
$checkbox10.TabIndex = 14
$checkbox10.Text = "01_Server_Triggers"
$checkbox10.Add_CheckStateChanged({
    if ($checkbox10.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox11 = New-Object System.Windows.Forms.CheckBox
$checkbox11.AutoSize = $True
$checkbox11.Location = New-Object System.Drawing.Point(20, 320)
$checkbox11.Name = "checkbox11"
$checkbox11.TabIndex = 15
$checkbox11.Text = "02_Linked_Servers"
$checkbox11.Add_CheckStateChanged({
    if ($checkbox11.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox12 = New-Object System.Windows.Forms.CheckBox
$checkbox12.AutoSize = $True
$checkbox12.Location = New-Object System.Drawing.Point(20, 340)
$checkbox12.Name = "checkbox12"
$checkbox12.TabIndex = 16
$checkbox12.Text = "03_NET_Assemblies"
$checkbox12.Add_CheckStateChanged({
    if ($checkbox12.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox13 = New-Object System.Windows.Forms.CheckBox
$checkbox13.AutoSize = $True
$checkbox13.Location = New-Object System.Drawing.Point(20, 360)
$checkbox13.Name = "checkbox13"
$checkbox13.TabIndex = 17
$checkbox13.Text = "04_Agent_Alerts"
$checkbox13.Add_CheckStateChanged({
    if ($checkbox13.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox14 = New-Object System.Windows.Forms.CheckBox
$checkbox14.AutoSize = $True
$checkbox14.Location = New-Object System.Drawing.Point(20, 375)
$checkbox14.Name = "checkbox14"
$checkbox14.TabIndex = 18
$checkbox14.Text = "04_Agent_Jobs"
$checkbox14.Add_CheckStateChanged({
    if ($checkbox14.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox15 = New-Object System.Windows.Forms.CheckBox
$checkbox15.AutoSize = $True
$checkbox15.Location = New-Object System.Drawing.Point(20, 390)
$checkbox15.Name = "checkbox15"
$checkbox15.TabIndex = 19
$checkbox15.Text = "04_Agent_Operators"
$checkbox15.Add_CheckStateChanged({
    if ($checkbox15.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox16 = New-Object System.Windows.Forms.CheckBox
$checkbox16.AutoSize = $True
$checkbox16.Location = New-Object System.Drawing.Point(20, 405)
$checkbox16.Name = "checkbox16"
$checkbox16.TabIndex = 20
$checkbox16.Text = "04_Agent_Proxies"
$checkbox16.Add_CheckStateChanged({
    if ($checkbox16.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox17 = New-Object System.Windows.Forms.CheckBox
$checkbox17.AutoSize = $True
$checkbox17.Location = New-Object System.Drawing.Point(20, 420)
$checkbox17.Name = "checkbox17"
$checkbox17.TabIndex = 21
$checkbox17.Text = "04_Agent_Schedules"
$checkbox17.Add_CheckStateChanged({
    if ($checkbox17.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox18 = New-Object System.Windows.Forms.CheckBox
$checkbox18.AutoSize = $True
$checkbox18.Location = New-Object System.Drawing.Point(20, 440)
$checkbox18.Name = "checkbox18"
$checkbox18.TabIndex = 22
$checkbox18.Text = "05_DBMail_Accounts"
$checkbox18.Add_CheckStateChanged({
    if ($checkbox18.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox19 = New-Object System.Windows.Forms.CheckBox
$checkbox19.AutoSize = $True
$checkbox19.Location = New-Object System.Drawing.Point(20, 455)
$checkbox19.Name = "checkbox19"
$checkbox19.TabIndex = 23
$checkbox19.Text = "05_DBMail_Profiles"
$checkbox19.Add_CheckStateChanged({
    if ($checkbox19.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox20 = New-Object System.Windows.Forms.CheckBox
$checkbox20.AutoSize = $True
$checkbox20.Location = New-Object System.Drawing.Point(20, 475)
$checkbox20.Name = "checkbox20"
$checkbox20.TabIndex = 24
$checkbox20.Text = "06_Query_Plan_Cache"
$checkbox20.Add_CheckStateChanged({
    if ($checkbox20.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox21 = New-Object System.Windows.Forms.CheckBox
$checkbox21.AutoSize = $True
$checkbox21.Location = New-Object System.Drawing.Point(20, 490)
$checkbox21.Name = "checkbox21"
$checkbox21.TabIndex = 25
$checkbox21.Text = "06_Top_25_Worst_Queries"
$checkbox21.Add_CheckStateChanged({
    if ($checkbox21.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox22 = New-Object System.Windows.Forms.CheckBox
$checkbox22.AutoSize = $True
$checkbox22.Location = New-Object System.Drawing.Point(20, 510)
$checkbox22.Name = "checkbox22"
$checkbox22.TabIndex = 26
$checkbox22.Text = "07_Service_Creds"
$checkbox22.Add_CheckStateChanged({
    if ($checkbox22.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox23 = New-Object System.Windows.Forms.CheckBox
$checkbox23.AutoSize = $True
$checkbox23.Location = New-Object System.Drawing.Point(20, 530)
$checkbox23.Name = "checkbox23"
$checkbox23.TabIndex = 27
$checkbox23.Text = "09_SSIS_Packages_from_MSDB"
$checkbox23.Add_CheckStateChanged({
    if ($checkbox23.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox24 = New-Object System.Windows.Forms.CheckBox
$checkbox24.AutoSize = $True
$checkbox24.Location = New-Object System.Drawing.Point(20, 545)
$checkbox24.Name = "checkbox24"
$checkbox24.TabIndex = 28
$checkbox24.Text = "09_SSIS_Packages_from_SSISDB"
$checkbox24.Add_CheckStateChanged({
    if ($checkbox24.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

# Column 2
$checkbox25 = New-Object System.Windows.Forms.CheckBox
$checkbox25.AutoSize = $True
$checkbox25.Location = New-Object System.Drawing.Point(225, 165)
$checkbox25.Name = "checkbox25"
$checkbox25.TabIndex = 29
$checkbox25.Text = "10_SSAS_Objects"
$checkbox25.Add_CheckStateChanged({
    if ($checkbox25.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox26 = New-Object System.Windows.Forms.CheckBox
$checkbox26.AutoSize = $True
$checkbox26.Location = New-Object System.Drawing.Point(225, 185)
$checkbox26.Name = "checkbox26"
$checkbox26.TabIndex = 30
$checkbox26.Text = "11_SSRS_Objects"
$checkbox26.Add_CheckStateChanged({
    if ($checkbox26.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox27 = New-Object System.Windows.Forms.CheckBox
$checkbox27.AutoSize = $True
$checkbox27.Location = New-Object System.Drawing.Point(225, 205)
$checkbox27.Name = "checkbox27"
$checkbox27.TabIndex = 31
$checkbox27.Text = "12_Security_Audit"
$checkbox27.Add_CheckStateChanged({
    if ($checkbox27.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox28 = New-Object System.Windows.Forms.CheckBox
$checkbox28.AutoSize = $True
$checkbox28.Location = New-Object System.Drawing.Point(225, 225)
$checkbox28.Name = "checkbox28"
$checkbox28.TabIndex = 32
$checkbox28.Text = "13_PKI"
$checkbox28.Add_CheckStateChanged({
    if ($checkbox28.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox29 = New-Object System.Windows.Forms.CheckBox
$checkbox29.AutoSize = $True
$checkbox29.Location = New-Object System.Drawing.Point(225, 245)
$checkbox29.Name = "checkbox29"
$checkbox29.TabIndex = 33
$checkbox29.Text = "14_Service_Broker"
$checkbox29.Add_CheckStateChanged({
    if ($checkbox29.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox30 = New-Object System.Windows.Forms.CheckBox
$checkbox30.AutoSize = $True
$checkbox30.Location = New-Object System.Drawing.Point(225, 265)
$checkbox30.Name = "checkbox30"
$checkbox30.TabIndex = 34
$checkbox30.Text = "15_Extended_Events"
$checkbox30.Add_CheckStateChanged({
    if ($checkbox30.Checked) {
        $cb_AllScripts.Checked = $false
    }
})

$checkbox31 = New-Object System.Windows.Forms.CheckBox
$checkbox31.AutoSize = $True
$checkbox31.Location = New-Object System.Drawing.Point(225, 285)
$checkbox31.Name = "checkbox31"
$checkbox31.TabIndex = 35
$checkbox31.Text = "16_Audits"
$checkbox31.Add_CheckStateChanged({
    if ($checkbox31.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox32 = New-Object System.Windows.Forms.CheckBox
$checkbox32.AutoSize = $True
$checkbox32.Location = New-Object System.Drawing.Point(225, 305)
$checkbox32.Name = "checkbox32"
$checkbox32.TabIndex = 36
$checkbox32.Text = "17_Managed_Backups"
$checkbox32.Add_CheckStateChanged({
    if ($checkbox32.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox33 = New-Object System.Windows.Forms.CheckBox
$checkbox33.AutoSize = $True
$checkbox33.Location = New-Object System.Drawing.Point(225, 325)
$checkbox33.Name = "checkbox33"
$checkbox33.TabIndex = 37
$checkbox33.Text = "18_Replication"
$checkbox33.Enabled = $false
$checkbox33.Add_CheckStateChanged({
    if ($checkbox33.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox34 = New-Object System.Windows.Forms.CheckBox
$checkbox34.AutoSize = $True
$checkbox34.Location = New-Object System.Drawing.Point(225, 345)
$checkbox34.Name = "checkbox34"
$checkbox34.TabIndex = 38
$checkbox34.Text = "19_AlwaysOn"
$checkbox34.Enabled = $false
$checkbox34.Add_CheckStateChanged({
    if ($checkbox34.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox35 = New-Object System.Windows.Forms.CheckBox
$checkbox35.AutoSize = $True
$checkbox35.Location = New-Object System.Drawing.Point(225, 365)
$checkbox35.Name = "checkbox35"
$checkbox35.TabIndex = 39
$checkbox35.Text = "21_Dac_Packages"
$checkbox35.Add_CheckStateChanged({
    if ($checkbox35.Checked) {
        $cb_AllScripts.Checked = $false
    }
})


$checkbox36 = New-Object System.Windows.Forms.CheckBox
$checkbox36.AutoSize = $True
$checkbox36.Location = New-Object System.Drawing.Point(225, 385)
$checkbox36.Name = "checkbox36"
$checkbox36.TabIndex = 40
$checkbox36.Text = "22_Policy_Based_Mgmt"
$checkbox36.Add_CheckStateChanged({
    if ($checkbox36.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox37 = New-Object System.Windows.Forms.CheckBox
$checkbox37.AutoSize = $True
$checkbox37.Location = New-Object System.Drawing.Point(225, 405)
$checkbox37.Name = "checkbox37"
$checkbox37.TabIndex = 41
$checkbox37.Text = "23_Database_Diagrams"
$checkbox37.Add_CheckStateChanged({
    if ($checkbox37.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox38 = New-Object System.Windows.Forms.CheckBox
$checkbox38.AutoSize = $True
$checkbox38.Location = New-Object System.Drawing.Point(225, 425)
$checkbox38.Name = "checkbox38"
$checkbox38.TabIndex = 42
$checkbox38.Text = "24_Plan_Guides"
$checkbox38.Add_CheckStateChanged({
    if ($checkbox38.Checked) {
        $cb_AllScripts.Checked = $false
    }
})




$checkbox39 = New-Object System.Windows.Forms.CheckBox
$checkbox39.AutoSize = $True
$checkbox39.Location = New-Object System.Drawing.Point(225, 445)
$checkbox39.Name = "checkbox39"
$checkbox39.TabIndex = 43
$checkbox39.Text = "30_DataBase_Objects"
$checkbox39.Font = $myFont
$checkbox39.Add_CheckStateChanged({
    if ($checkbox39.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox40 = New-Object System.Windows.Forms.CheckBox
$checkbox40.AutoSize = $True
$checkbox40.Location = New-Object System.Drawing.Point(225, 465)
$checkbox40.Name = "checkbox40"
$checkbox40.TabIndex = 44
$checkbox40.Text = "31_DataBase_Export_Table_Data"
$checkbox40.Add_CheckStateChanged({
    if ($checkbox40.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox41 = New-Object System.Windows.Forms.CheckBox
$checkbox41.AutoSize = $True
$checkbox41.Location = New-Object System.Drawing.Point(225, 485)
$checkbox41.Name = "checkbox41"
$checkbox41.TabIndex = 45
$checkbox41.Text = "32_Database_Recovery_Models"
$checkbox41.Add_CheckStateChanged({
    if ($checkbox41.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox42 = New-Object System.Windows.Forms.CheckBox
$checkbox42.AutoSize = $True
$checkbox42.Location = New-Object System.Drawing.Point(225, 505)
$checkbox42.Name = "checkbox42"
$checkbox42.TabIndex = 46
$checkbox42.Text = "33_VLF_Count"
$checkbox42.Add_CheckStateChanged({
    if ($checkbox42.Checked) {
        $cb_AllScripts.Checked = $false
    }
})



$checkbox43 = New-Object System.Windows.Forms.CheckBox
$checkbox43.AutoSize = $True
$checkbox43.Location = New-Object System.Drawing.Point(225, 525)
$checkbox43.Name = "checkbox43"
$checkbox43.TabIndex = 47
$checkbox43.Text = "34_User_Objects_in_MasterDB"
$checkbox43.Add_CheckStateChanged({
    if ($checkbox43.Checked) {
        $cb_AllScripts.Checked = $false
    }
})












# Add the controls to the Form
$form.controls.add($pictureBox)
$Form.Controls.Add($Label1)
$Form.Controls.Add($Label2)
$Form.Controls.Add($Label3)
$Form.Controls.Add($Label4)
$Form.Controls.Add($myUserText)
$Form.Controls.Add($myPassText)
$Form.Controls.Add($myServerText)
$Form.Controls.Add($cb_AllScripts)
$Form.Controls.Add($checkbox1)
$Form.Controls.Add($checkbox2)
$Form.Controls.Add($checkbox3)
$Form.Controls.Add($checkbox4)
$Form.Controls.Add($checkbox5)
$Form.Controls.Add($checkbox6)
$Form.Controls.Add($checkbox7)
$Form.Controls.Add($checkbox8)
$Form.Controls.Add($checkbox9)
$Form.Controls.Add($checkbox10)
$Form.Controls.Add($checkbox11)
$Form.Controls.Add($checkbox12)
$Form.Controls.Add($checkbox13)
$Form.Controls.Add($checkbox14)
$Form.Controls.Add($checkbox15)
$Form.Controls.Add($checkbox16)
$Form.Controls.Add($checkbox17)
$Form.Controls.Add($checkbox18)
$Form.Controls.Add($checkbox19)
$Form.Controls.Add($checkbox20)
$Form.Controls.Add($checkbox21)
$Form.Controls.Add($checkbox22)
$Form.Controls.Add($checkbox23)
$Form.Controls.Add($checkbox24)
$Form.Controls.Add($checkbox25)
$Form.Controls.Add($checkbox26)
$Form.Controls.Add($checkbox27)
$Form.Controls.Add($checkbox28)
$Form.Controls.Add($checkbox29)
$Form.Controls.Add($checkbox30)
$Form.Controls.Add($checkbox31)
$Form.Controls.Add($checkbox32)
$Form.Controls.Add($checkbox33)
$Form.Controls.Add($checkbox34)
$Form.Controls.Add($checkbox35)
$Form.Controls.Add($checkbox36)
$Form.Controls.Add($checkbox37)
$Form.Controls.Add($checkbox38)
$Form.Controls.Add($checkbox39)
$Form.Controls.Add($checkbox40)
$Form.Controls.Add($checkbox41)
$Form.Controls.Add($checkbox42)
$Form.Controls.Add($checkbox43)

$Form.Controls.Add($myServerText)
$Form.Controls.Add($GoButton)
$Form.Controls.Add($CancelButton)



# Display the dialog
$form.ShowDialog()

# Return To Base
set-location $BaseFolder

    
$Auth="win"
If ($myUserText.text.Length -gt 0 -and $myPassText.Text.Length -gt 0)
{
    $Auth = "sql"
}


if($cb_AllScripts.Checked)
	{
		
        If ($auth -eq "sql")
        {
            & .\00_RunAllScripts.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\00_RunAllScripts.ps1 $myServerText.Text
        }
	}

if($checkbox1.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Appliance.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Appliance.ps1 $myServerText.Text
        }
        
    }

if($checkbox2.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Credentials.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Credentials.ps1 $myServerText.Text
        }
        
    }	

if($checkbox3.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Logins.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Logins.ps1 $myServerText.Text
        }
        
    }	

if($checkbox4.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Resource_Governor.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Resource_Governor.ps1 $myServerText.Text
        }
        
    }	

if($checkbox5.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Roles.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Roles.ps1 $myServerText.Text
        }
        
    }	

if($checkbox6.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Settings.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Settings.ps1 $myServerText.Text
        }
        
    }	

if($checkbox7.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Shares.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Shares.ps1 $myServerText.Text
        }
        
    }	


if($checkbox8.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Startup_Procs.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Startup_Procs.ps1 $myServerText.Text
        }
        
    }	


if($checkbox9.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Storage.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Storage.ps1 $myServerText.Text
        }
        
    }	

if($checkbox10.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\01_Server_Triggers.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\01_Server_Triggers.ps1 $myServerText.Text
        }
        
    }	

if($checkbox11.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\02_Linked_Servers.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\02_Linked_Servers.ps1 $myServerText.Text
        }
        
    }	


if($checkbox12.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\03_NET_Assemblies.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\03_NET_Assemblies.ps1 $myServerText.Text
        }
        
    }	

if($checkbox13.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\04_Agent_Alerts.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\04_Agent_Alerts.ps1 $myServerText.Text
        }
        
    }	

if($checkbox14.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\04_Agent_Jobs.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\04_Agent_Jobs.ps1 $myServerText.Text
        }
        
    }	

if($checkbox15.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\04_Agent_Operators.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\04_Agent_Operators.ps1 $myServerText.Text
        }
        
    }	


if($checkbox16.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\04_Agent_Proxies.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\04_Agent_Proxies.ps1 $myServerText.Text
        }
        
    }	


if($checkbox17.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\04_Agent_Schedules.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\04_Agent_Schedules.ps1 $myServerText.Text
        }
        
    }	


if($checkbox18.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\05_DBMail_Accounts.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\05_DBMail_Accounts.ps1 $myServerText.Text
        }
        
    }	


if($checkbox19.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\05_DBMail_Profiles.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\05_DBMail_Profiles.ps1 $myServerText.Text
        }
        
    }	

if($checkbox20.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\06_Query_Plan_Cache.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\06_Query_Plan_Cache.ps1 $myServerText.Text
        }
        
    }	


if($checkbox21.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\06_Top_25_Worst_Queries.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\06_Top_25_Worst_Queries.ps1 $myServerText.Text
        }
        
    }	


if($checkbox22.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\07_Service_Creds.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\07_Service_Creds.ps1 $myServerText.Text
        }
        
    }	



if($checkbox23.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\09_SSIS_Packages_from_MSDB.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\09_SSIS_Packages_from_MSDB.ps1 $myServerText.Text
        }
        
    }	


if($checkbox24.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\09_SSIS_Packages_from_SSISDB.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\09_SSIS_Packages_from_SSISDB.ps1 $myServerText.Text
        }
        
    }	

if($checkbox25.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\10_SSAS_Objects.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\10_SSAS_Objects.ps1 $myServerText.Text
        }
        
    }	


if($checkbox26.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\11_SSRS_Objects.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\11_SSRS_Objects.ps1 $myServerText.Text
        }
        
    }	


if($checkbox27.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\12_Security_Audit.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\12_Security_Audit.ps1 $myServerText.Text
        }
        
    }	



if($checkbox28.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\13_PKI.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\13_PKI.ps1 $myServerText.Text
        }
        
    }	



if($checkbox29.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\14_Service_Broker.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\14_Service_Broker.ps1 $myServerText.Text
        }
        
    }	

if($checkbox30.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\15_Extended_Events.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\15_Extended_Events.ps1 $myServerText.Text
        }
        
    }	



if($checkbox31.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\16_Audits.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\16_Audits.ps1 $myServerText.Text
        }
        
    }	



if($checkbox32.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\17_Managed_Backups.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\17_Managed_Backups.ps1 $myServerText.Text
        }
        
    }	



if($checkbox33.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\18_Replication.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\18_Replication.ps1 $myServerText.Text
        }
        
    }	


if($checkbox34.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\19_AlwaysOn.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\19_AlwaysOn.ps1 $myServerText.Text
        }
        
    }	


if($checkbox35.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\21_Dac_Packages.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\21_Dac_Packages.ps1 $myServerText.Text
        }
        
    }	


if($checkbox36.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\22_Policy_Based_Mgmt.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\22_Policy_Based_Mgmt.ps1 $myServerText.Text
        }
        
    }	


if($checkbox37.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\23_Database_Diagrams.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\23_Database_Diagrams.ps1 $myServerText.Text
        }
        
    }	


if($checkbox38.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\24_Plan_Guides.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\24_Plan_Guides.ps1 $myServerText.Text
        }
        
    }	


if($checkbox39.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\30_DataBase_Objects.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\30_DataBase_Objects.ps1 $myServerText.Text
        }
        
    }	


if($checkbox40.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\31_DataBase_Export_Table_Data.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\31_DataBase_Export_Table_Data.ps1 $myServerText.Text
        }
        
    }	


if($checkbox41.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\32_Database_Recovery_Models.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\32_Database_Recovery_Models.ps1 $myServerText.Text
        }
        
    }	


if($checkbox42.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\33_VLF_Count.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\33_VLF_Count.ps1 $myServerText.Text
        }
        
    }	

if($checkbox43.Checked)
	{
        if ($Auth -eq "sql")
        {
            & .\34_User_Objects_in_Master.ps1 $myServerText.Text $myUserText.Text $myPassText.Text
        }
        else
        {
            & .\34_User_Objects_in_Master.ps1 $myServerText.Text
        }
        
    }	

exit