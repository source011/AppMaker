# Hide Powershell window
$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

# Set size of window
$host.UI.RawUI.WindowSize = new-object System.Management.Automation.Host.Size(50,10)

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")


# Vars
$appName = "AppMaker"
$buildLocation = "$PSSCRIPTROOT\DropFilesHere"
$outputLocation = "$PSSCRIPTROOT\COMPLETE"
$templateLocation ="$PSSCRIPTROOT\bin"

# Create folders if not already exists
if(!(Test-Path $buildLocation)){
	New-Item $buildLocation -Type Directory | Out-Null
}
if(!(Test-Path $outputLocation)){
	New-Item $outputLocation -Type Directory | Out-Null
}


$installerCount = 0

##############################################################################
$appMaker.StartPosition = "CenterScreen"
$appMaker = New-Object system.Windows.Forms.Form
$appMaker.Text = $appName
$appMaker.TopMost = $true
$appMaker.Width = 339
$appMaker.Height = 170
$appMaker.FormBorderStyle = 'Fixed3D'
$appMaker.MaximizeBox = $false
##############################################################################
$appNameLabel = New-Object system.windows.Forms.Label
$appNameLabel.Text = "Name"
$appNameLabel.AutoSize = $true
$appNameLabel.Width = 25
$appNameLabel.Height = 10
$appNameLabel.location = new-object system.drawing.point(2,3)
$appNameLabel.Font = "Microsoft Sans Serif,10"
$appMaker.controls.Add($appNameLabel)

$appNameTextbox = New-Object system.windows.Forms.TextBox
$appNameTextbox.Width = 225
$appNameTextbox.Height = 20
$appNameTextbox.location = new-object system.drawing.point(82,3)
$appNameTextbox.Font = "Microsoft Sans Serif,10"
$appMaker.controls.Add($appNameTextbox)
##############################################################################
$appExeLabel = New-Object system.windows.Forms.Label
$appExeLabel.Text = "Installer"
$appExeLabel.AutoSize = $true
$appExeLabel.Width = 25
$appExeLabel.Height = 10
$appExeLabel.location = new-object system.drawing.point(2,30)
$appExeLabel.Font = "Microsoft Sans Serif,10"
$appMaker.controls.Add($appExeLabel)

$appExeTextbox = New-Object system.windows.Forms.ComboBox
$appExeTextbox.Width = 225
$appExeTextbox.Height = 20
$appExeTextbox.location = new-object system.drawing.point(82,30)
$appExeTextbox.Font = "Microsoft Sans Serif,10"
$files = @(Get-ChildItem "$($buildLocation)\*" -Include *.ps1,*.vbs,*.bat)
foreach ($file in $files){
	$appExeTextbox.Items.add($file.name)
}
$appExeTextbox.SelectedItem = $appExeTextbox.Items[0]
#$appExeTextbox.Text = "SELECT INSTALLER"
$appMaker.controls.Add($appExeTextbox)
##############################################################################
$appVersionLabel = New-Object system.windows.Forms.Label
$appVersionLabel.Text = "Version"
$appVersionLabel.AutoSize = $true
$appVersionLabel.Width = 25
$appVersionLabel.Height = 10
$appVersionLabel.location = new-object system.drawing.point(3,56)
$appVersionLabel.Font = "Microsoft Sans Serif,10"
$appMaker.controls.Add($appVersionLabel)

$appVersionTextbox = New-Object system.windows.Forms.TextBox
$appVersionTextbox.Width = 225
$appVersionTextbox.Height = 20
$appVersionTextbox.location = new-object system.drawing.point(82,56)
$appVersionTextbox.Font = "Microsoft Sans Serif,10"
$appMaker.controls.Add($appVersionTextbox)
##############################################################################

$createButton = New-Object system.windows.Forms.Button
$createButton.location = new-object system.drawing.point(205,82)
$createButton.Font = "Microsoft Sans Serif,10"
$createButton.Size = New-Object System.Drawing.Size(100,30)
$createButton.Text = "Create App"

# Check if multiple installers exists
if($installerCount -gt 1){
 [System.Windows.Forms.MessageBox]::Show("Multiple installers found! We only need one...","$appName",1,48)
 	$appExeTextbox.Text = "Remove unwanted installers!"
	$appExeTextbox.Enabled = $false
	$appNameTextbox.Text = "Remove unwanted installers!"
	$appNameTextbox.Enabled = $false
	$appVersionTextbox.Text = "Remove unwanted installers!"
	$appVersionTextbox.Enabled = $false

	$createButton.Enabled = $false
}

# Check if installer is existing at all
$count = ($files | Measure-Object).count
if($count -lt 1) {
	$appExeTextbox.Text = "No valid installer found!"
	$appExeTextbox.Enabled = $false
	$appNameTextbox.Text = "No valid installer found!"
	$appNameTextbox.Enabled = $false
	$appVersionTextbox.Text = "No valid installer found!"
	$appVersionTextbox.Enabled = $false
	$createButton.Enabled = $false
}

$createButton.Add_Click({
#add here code triggered by the event


IF([string]::IsNullOrWhiteSpace($appNameTextbox.text) -OR [string]::IsNullOrWhiteSpace($appExeTextbox.text) -OR [string]::IsNullOrWhiteSpace($appVersionTextbox.text)){            
    [System.Windows.Forms.MessageBox]::Show("Make sure that no fields are blank..","$appName",1,48)            
} else {

# Get input for package
$applicationName = $appNameTextbox.text
$applicationName = $applicationName.replace(" ","_")
$applicationExe = $appExeTextbox.text
$applicationVersion = $appVersionTextbox.text
$date = Get-Date -format "yyyy-MM-dd"

# Set fodler for "complete"
$applicationPath = "$outputLocation\$applicationName\$applicationVersion - $date"
if(!(Test-path $applicationPath)){
New-Item $applicationPath -Type Directory
}

################################## BUILD ########################################################################################
$date = Get-Date -format "yyyy-MM-dd"
$folderLoc = $buildLocation

if(!(Test-path $folderLoc)){
New-Item "$folderLoc" -Type Directory | Out-Null
}

# Copy config for EXE installer to build folder
$config = @"
;!@Install@!UTF-8!
Title="$applicationName"
Progress="no"
RunProgram="$applicationExe"
;!@InstallEnd@!
"@
$config | Out-File -encoding ascii "$folderLoc\config.txt"

# Copy required sfx file to build folder
Copy-Item "$templateLocation\7zS.sfx" -Destination "$folderLoc\7zS.sfx"

# Compress raw installer files
if (-not (test-path "$templateLocation\7-Zip\7z.exe")) {throw "$templateLocation\7-Zip\7z.exe needed"}
set-alias sz "$templateLocation\7-Zip\7z.exe"
$zipFile = "temp.7z"
sz a -r "$folderLoc\$zipFile" "$folderLoc\*.*" | Out-Null

# Create EXE installer from compressed archive
$command = @'
cmd.exe /C copy /b "$folderLoc\7zS.sfx" + "$folderLoc\config.txt" + "$folderLoc\$zipFile" "$folderLoc\$($applicationName)_$($applicationVersion).exe"
'@

Invoke-Expression -Command:$command | Out-Null



# Remove all files

if(Test-Path "$folderLoc\$($applicationName)_$($applicationVersion).exe"){
	Get-ChildItem -Path  "$folderLoc" -Recurse -exclude "$($applicationName)_$($applicationVersion).exe" | Remove-Item -force -recurse
	Move-Item "$folderLoc\$($applicationName)_$($applicationVersion).exe" -Destination "$applicationPath\$($applicationName)_$($applicationVersion).exe"
}
#################################################################################################################################


# Prompt created app

if(Test-path "$applicationPath\$($applicationName)_$($applicationVersion).exe"){
[System.Windows.Forms.MessageBox]::Show("The app $applicationName was created successfully!","$appName",1,48)
ii "$PSSCRIPTROOT\COMPLETE"
$appMaker.Dispose()
} else {
[System.Windows.Forms.MessageBox]::Show("ERROR! Something went wrong with the build - $applicationName could not be created!","$appName",1,48)
}

}

})
$appMaker.controls.Add($createButton)
[void]$appMaker.ShowDialog()
$appMaker.Dispose()