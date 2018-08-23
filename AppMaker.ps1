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

# Create MSI
$config4msi = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<DOCUMENT Type="Advanced Installer" CreateVersion="14.9" version="14.9" Modules="professional" RootPath="." Language="en" Id="{EBF016CE-1F65-4D89-9DA2-228931E5070C}">
  <COMPONENT cid="caphyon.advinst.msicomp.ProjectOptionsComponent">
    <ROW Name="HiddenItems" Value="AppXProductDetailsComponent;AppXDependenciesComponent;AppXAppDetailsComponent;AppXVisualAssetsComponent;AppXCapabilitiesComponent;AppXAppDeclarationsComponent;AppXUriRulesComponent;SccmComponent;UpdaterComponent;MsiUpgradeComponent;SerValComponent;MsiLaunchConditionsComponent;MsiJavaComponent;MsiExtComponent;MsiAssemblyComponent;MsiDriverPackagesComponent;MsiServInstComponent;ActSyncAppComponent;ScheduledTasksComponent;CPLAppletComponent;GameUxComponent;MsiClassComponent;WebApplicationsComponent;MsiOdbcDataSrcComponent;SqlConnectionComponent;SharePointSlnComponent;SilverlightSlnComponent"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiPropsComponent">
    <ROW Property="AI_BITMAP_DISPLAY_MODE" Value="0"/>
    <ROW Property="ALLUSERS" Value="1"/>
    <ROW Property="ARPCOMMENTS" Value="This installer database contains the logic and data required to install [|ProductName]." ValueLocId="*"/>
    <ROW Property="LIMITUI" Value="1"/>
    <ROW Property="Manufacturer" Value="$($applicationName)"/>
    <ROW Property="ProductCode" Value="1033:{89423650-26E4-45B6-B1FE-9BB39394A156} " Type="16"/>
    <ROW Property="ProductLanguage" Value="1033"/>
    <ROW Property="ProductName" Value="$($applicationName) $($applicationVersion)"/>
    <ROW Property="ProductVersion" Value="$($applicationVersion)" Type="32"/>
    <ROW Property="SecureCustomProperties" Value="OLDPRODUCTS;AI_NEWERPRODUCTFOUND"/>
    <ROW Property="UpgradeCode" Value="{A6318178-5020-4128-ABFC-40B507054919}"/>
    <ROW Property="WindowsType9X" MultiBuildValue="DefaultBuild:Windows 9x/ME" ValueLocId="-"/>
    <ROW Property="WindowsType9XDisplay" MultiBuildValue="DefaultBuild:Windows 9x/ME" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT40" MultiBuildValue="DefaultBuild:Windows NT 4.0" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT40Display" MultiBuildValue="DefaultBuild:Windows NT 4.0" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT50" MultiBuildValue="DefaultBuild:Windows 2000" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT50Display" MultiBuildValue="DefaultBuild:Windows 2000" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT5X" MultiBuildValue="DefaultBuild:Windows XP/2003 RTM, Windows XP/2003 SP1, Windows XP SP2 x86" ValueLocId="-"/>
    <ROW Property="WindowsTypeNT5XDisplay" MultiBuildValue="DefaultBuild:Windows XP/2003 RTM, Windows XP/2003 SP1, Windows XP SP2 x86" ValueLocId="-"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiDirsComponent">
    <ROW Directory="APPDIR" Directory_Parent="TARGETDIR" DefaultDir="APPDIR:." IsPseudoRoot="1"/>
    <ROW Directory="TARGETDIR" DefaultDir="SourceDir"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiCompsComponent">
    <ROW Component="$($applicationName)" ComponentId="{8287FF1D-BB1B-423B-A1DD-960F1DA1A755}" Directory_="APPDIR" Attributes="4" KeyPath="$($applicationName)" Options="2"/>
    <ROW Component="ProductInformation" ComponentId="{A1900F41-9360-43D0-B4A6-35289B005047}" Directory_="APPDIR" Attributes="4" KeyPath="Version"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiFeatsComponent">
    <ROW Feature="$($applicationName)" Title="$($applicationName) $($applicationVersion)" Description="$($applicationName) $($applicationVersion)" Display="3" Level="1" Attributes="0" Components="$($applicationName)"/>
    <ROW Feature="MainFeature" Title="MainFeature" Description="Description" Display="1" Level="1" Directory_="APPDIR" Attributes="0" Components="ProductInformation"/>
    <ATTRIBUTE name="CurrentFeature" value="MainFeature"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.BootstrOptComponent">
    <ROW BootstrOptKey="GlobalOptions" DownloadFolder="[AppDataFolder][|Manufacturer]\[|ProductName]\prerequisites" Options="2"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.BuildComponent">
    <ROW BuildKey="DefaultBuild" BuildName="DefaultBuild" BuildOrder="1" BuildType="1" PackageFolder="." Languages="en" InstallationType="4" UseLargeSchema="true"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.DictionaryComponent">
    <ROW Path="&lt;AI_DICTS&gt;ui.ail"/>
    <ROW Path="&lt;AI_DICTS&gt;ui_en.ail"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.FragmentComponent">
    <ROW Fragment="CommonUI.aip" Path="&lt;AI_FRAGS&gt;CommonUI.aip"/>
    <ROW Fragment="FolderDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\FolderDlg.aip"/>
    <ROW Fragment="MaintenanceTypeDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\MaintenanceTypeDlg.aip"/>
    <ROW Fragment="MaintenanceWelcomeDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\MaintenanceWelcomeDlg.aip"/>
    <ROW Fragment="SequenceDialogs.aip" Path="&lt;AI_THEMES&gt;classic\fragments\SequenceDialogs.aip"/>
    <ROW Fragment="Sequences.aip" Path="&lt;AI_FRAGS&gt;Sequences.aip"/>
    <ROW Fragment="StaticUIStrings.aip" Path="&lt;AI_FRAGS&gt;StaticUIStrings.aip"/>
    <ROW Fragment="UI.aip" Path="&lt;AI_THEMES&gt;classic\fragments\UI.aip"/>
    <ROW Fragment="Validation.aip" Path="&lt;AI_FRAGS&gt;Validation.aip"/>
    <ROW Fragment="VerifyRemoveDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\VerifyRemoveDlg.aip"/>
    <ROW Fragment="VerifyRepairDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\VerifyRepairDlg.aip"/>
    <ROW Fragment="WelcomeDlg.aip" Path="&lt;AI_THEMES&gt;classic\fragments\WelcomeDlg.aip"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiActionTextComponent">
    <ROW Action="AI_ConfigureChainer" Description="Configuring prerequisites launcher" DescriptionLocId="ActionText.Description.AI_ConfigureChainer" Template="Configure Launcher" TemplateLocId="ActionText.Template.AI_ConfigureChainer"/>
    <ROW Action="AI_DownloadPrereq" Description="Downloading prerequisite software" DescriptionLocId="ActionText.Description.AI_DownloadPrereq" Template="Downloading [1]{[2] completed}" TemplateLocId="ActionText.Template.AI_DownloadPrereq"/>
    <ROW Action="AI_ExtractPrereq" Description="Extracting prerequisite software" DescriptionLocId="ActionText.Description.AI_ExtractPrereq" Template="Extracting [1]{[2] completed}" TemplateLocId="ActionText.Template.AI_ExtractPrereq"/>
    <ROW Action="AI_InstallPostPrerequisite" Description="Installing prerequisite software" DescriptionLocId="ActionText.Description.AI_InstallPrerequisite" Template="Installing [1]{[2] completed}" TemplateLocId="ActionText.Template.AI_InstallPrerequisite"/>
    <ROW Action="AI_InstallPrerequisite" Description="Installing prerequisite software" DescriptionLocId="ActionText.Description.AI_InstallPrerequisite" Template="Installing [1]{[2] completed}" TemplateLocId="ActionText.Template.AI_InstallPrerequisite"/>
    <ROW Action="AI_VerifyPrereq" Description="Verifying prerequisites" DescriptionLocId="ActionText.Description.AI_VerifyPrereq" Template="[1] was not installed correctly." TemplateLocId="ActionText.Template.AI_VerifyPrereq"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiBinaryComponent">
    <ROW Name="Prereq.dll" SourcePath="&lt;AI_CUSTACTS&gt;Prereq.dll"/>
    <ROW Name="aicustact.dll" SourcePath="&lt;AI_CUSTACTS&gt;aicustact.dll"/>
    <ROW Name="aipackagechainer.exe" SourcePath="&lt;AI_CUSTACTS&gt;aipackagechainer.exe"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiControlEventComponent">
    <ROW Dialog_="AdminBrowseDlg" Control_="Cancel" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="AdminBrowseDlg#Cancel#EndDialog#Return#1"/>
    <ROW Dialog_="AdminBrowseDlg" Control_="OK" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="AdminBrowseDlg#OK#EndDialog#Return#1"/>
    <ROW Dialog_="AdminBrowseDlg" Control_="OK" Event="SetTargetPath" Argument="TARGETDIR" Condition="1" Ordering="100" MsiKey="AdminBrowseDlg#OK#SetTargetPath#TARGETDIR#1"/>
    <ROW Dialog_="AdminInstallPointDlg" Control_="Next" Event="SetTargetPath" Argument="TARGETDIR" Condition="1" Ordering="100" MsiKey="AdminInstallPointDlg#Next#SetTargetPath#TARGETDIR#1"/>
    <ROW Dialog_="AdminWelcomeDlg" Control_="Next" Event="[InstallMode]" Argument="Server Image" Condition="1" Ordering="100" MsiKey="AdminWelcomeDlg#Next#[InstallMode]#Server Image#1"/>
    <ROW Dialog_="BrowseDlg" Control_="Cancel" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="BrowseDlg#Cancel#EndDialog#Return#1"/>
    <ROW Dialog_="BrowseDlg" Control_="OK" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="BrowseDlg#OK#EndDialog#Return#1"/>
    <ROW Dialog_="BrowseDlg" Control_="OK" Event="SetTargetPath" Argument="[_BrowseProperty]" Condition="1" Ordering="100" MsiKey="BrowseDlg#OK#SetTargetPath#[_BrowseProperty]#1"/>
    <ROW Dialog_="CancelDlg" Control_="No" Event="EndDialog" Argument="Return" Condition="1" Ordering="100" MsiKey="CancelDlg#No#EndDialog#Return#1"/>
    <ROW Dialog_="CancelDlg" Control_="Yes" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="CancelDlg#Yes#EndDialog#Exit#1"/>
    <ROW Dialog_="CustomizeDlg" Control_="Next" Event="DoAction" Argument="AI_InstallModeCheck" Condition="AI_MAINT" Ordering="100" MsiKey="CustomizeDlg#Next#DoAction#AI_InstallModeCheck#AI_MAINT"/>
    <ROW Dialog_="DiskCostDlg" Control_="OK" Event="EndDialog" Argument="Return" Condition="1" Ordering="100" MsiKey="DiskCostDlg#OK#EndDialog#Return#1"/>
    <ROW Dialog_="ErrorDlg" Control_="A" Event="EndDialog" Argument="ErrorAbort" Condition="1" Ordering="100" MsiKey="ErrorDlg#A#EndDialog#ErrorAbort#1"/>
    <ROW Dialog_="ErrorDlg" Control_="C" Event="EndDialog" Argument="ErrorCancel" Condition="1" Ordering="100" MsiKey="ErrorDlg#C#EndDialog#ErrorCancel#1"/>
    <ROW Dialog_="ErrorDlg" Control_="I" Event="EndDialog" Argument="ErrorIgnore" Condition="1" Ordering="100" MsiKey="ErrorDlg#I#EndDialog#ErrorIgnore#1"/>
    <ROW Dialog_="ErrorDlg" Control_="N" Event="EndDialog" Argument="ErrorNo" Condition="1" Ordering="100" MsiKey="ErrorDlg#N#EndDialog#ErrorNo#1"/>
    <ROW Dialog_="ErrorDlg" Control_="O" Event="EndDialog" Argument="ErrorOk" Condition="1" Ordering="100" MsiKey="ErrorDlg#O#EndDialog#ErrorOk#1"/>
    <ROW Dialog_="ErrorDlg" Control_="R" Event="EndDialog" Argument="ErrorRetry" Condition="1" Ordering="100" MsiKey="ErrorDlg#R#EndDialog#ErrorRetry#1"/>
    <ROW Dialog_="ErrorDlg" Control_="Y" Event="EndDialog" Argument="ErrorYes" Condition="1" Ordering="100" MsiKey="ErrorDlg#Y#EndDialog#ErrorYes#1"/>
    <ROW Dialog_="ExitDialog" Control_="Finish" Event="DoAction" Argument="AI_LaunchApp" Condition="(RUNAPPLICATION=1) AND (AI_INSTALL OR AI_PATCH)" Ordering="200" MsiKey="ExitDialog#Finish#DoAction#AI_LaunchApp#(RUNAPPLICATION=1) AND (AI_INSTALL OR AI_PATCH)"/>
    <ROW Dialog_="ExitDialog" Control_="Finish" Event="DoAction" Argument="AI_ViewReadme" Condition="(VIEWREADME=1) AND (AI_INSTALL OR AI_PATCH)" Ordering="100" MsiKey="ExitDialog#Finish#DoAction#AI_ViewReadme#(VIEWREADME=1) AND (AI_INSTALL OR AI_PATCH)"/>
    <ROW Dialog_="ExitDialog" Control_="Finish" Event="EndDialog" Argument="Return" Condition="1" Ordering="300" MsiKey="ExitDialog#Finish#EndDialog#Return#1"/>
    <ROW Dialog_="ExitDialog" Control_="Cancel" Event="EndDialog" Argument="Return" Condition="1" Ordering="100" MsiKey="ExitDialog#Cancel#EndDialog#Return#1"/>
    <ROW Dialog_="FatalError" Control_="Finish" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="FatalError#Finish#EndDialog#Exit#1"/>
    <ROW Dialog_="FatalError" Control_="Finish" Event="DoAction" Argument="AI_SHOW_LOG" Condition="(MsiLogFileLocation AND AI_LOG_CHECKBOX)" Ordering="101" MsiKey="FatalError#Finish#DoAction#AI_SHOW_LOG#(MsiLogFileLocation AND AI_LOG_CHECKBOX)"/>
    <ROW Dialog_="FatalError" Control_="Cancel" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="FatalError#Cancel#EndDialog#Exit#1"/>
    <ROW Dialog_="FilesInUse" Control_="Exit" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="FilesInUse#Exit#EndDialog#Exit#1"/>
    <ROW Dialog_="FilesInUse" Control_="Ignore" Event="EndDialog" Argument="Ignore" Condition="1" Ordering="100" MsiKey="FilesInUse#Ignore#EndDialog#Ignore#1"/>
    <ROW Dialog_="FilesInUse" Control_="Retry" Event="EndDialog" Argument="Retry" Condition="1" Ordering="100" MsiKey="FilesInUse#Retry#EndDialog#Retry#1"/>
    <ROW Dialog_="OutOfDiskDlg" Control_="OK" Event="EndDialog" Argument="Return" Condition="1" Ordering="100" MsiKey="OutOfDiskDlg#OK#EndDialog#Return#1"/>
    <ROW Dialog_="OutOfRbDiskDlg" Control_="No" Event="EndDialog" Argument="Return" Condition="1" Ordering="100" MsiKey="OutOfRbDiskDlg#No#EndDialog#Return#1"/>
    <ROW Dialog_="OutOfRbDiskDlg" Control_="Yes" Event="EnableRollback" Argument="False" Condition="1" Ordering="100" MsiKey="OutOfRbDiskDlg#Yes#EnableRollback#False#1"/>
    <ROW Dialog_="OutOfRbDiskDlg" Control_="Yes" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="OutOfRbDiskDlg#Yes#EndDialog#Return#1"/>
    <ROW Dialog_="ResumeDlg" Control_="Install" Event="EnableRollback" Argument="False" Condition="OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;" Ordering="500" MsiKey="ResumeDlg#Install#EnableRollback#False#OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;"/>
    <ROW Dialog_="UserExit" Control_="Finish" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="UserExit#Finish#EndDialog#Exit#1"/>
    <ROW Dialog_="UserExit" Control_="Cancel" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="UserExit#Cancel#EndDialog#Exit#1"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Install" Event="EndDialog" Argument="Return" Condition="AI_ADMIN AND InstallMode = &quot;Server Image&quot;" Ordering="150" MsiKey="VerifyReadyDlg#Install#EndDialog#Return#AI_ADMIN AND InstallMode = &quot;Server Image&quot;"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Install" Event="EnableRollback" Argument="False" Condition="OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;" Ordering="400" MsiKey="VerifyReadyDlg#Install#EnableRollback#False#OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;"/>
    <ROW Dialog_="WaitForCostingDlg" Control_="Return" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="WaitForCostingDlg#Return#EndDialog#Exit#1"/>
    <ROW Dialog_="PatchWelcomeDlg" Control_="Next" Event="ReinstallMode" Argument="ecmus" Condition="AI_PATCH" Ordering="100" MsiKey="PatchWelcomeDlg#Next#ReinstallMode#ecmus#AI_PATCH"/>
    <ROW Dialog_="PatchWelcomeDlg" Control_="Next" Event="Reinstall" Argument="All" Condition="AI_PATCH" Ordering="200" MsiKey="PatchWelcomeDlg#Next#Reinstall#All#AI_PATCH"/>
    <ROW Dialog_="MsiRMFilesInUse" Control_="Cancel" Event="EndDialog" Argument="Exit" Condition="1" Ordering="100" MsiKey="MsiRMFilesInUse#Cancel#EndDialog#Exit#1"/>
    <ROW Dialog_="MsiRMFilesInUse" Control_="OK" Event="EndDialog" Argument="Return" Condition="1" Ordering="200" MsiKey="MsiRMFilesInUse#OK#EndDialog#Return#1"/>
    <ROW Dialog_="WelcomeDlg" Control_="Next" Event="NewDialog" Argument="FolderDlg" Condition="AI_INSTALL" Ordering="1"/>
    <ROW Dialog_="FolderDlg" Control_="Browse" Event="[_BrowseProperty]" Argument="APPDIR" Condition="1" Ordering="100" MsiKey="FolderDlg#Browse#[_BrowseProperty]#APPDIR#1"/>
    <ROW Dialog_="FolderDlg" Control_="Next" Event="SetTargetPath" Argument="APPDIR" Condition="1" Ordering="200" MsiKey="FolderDlg#Next#SetTargetPath#APPDIR#1"/>
    <ROW Dialog_="FolderDlg" Control_="Next" Event="NewDialog" Argument="VerifyReadyDlg" Condition="AI_INSTALL" Ordering="201"/>
    <ROW Dialog_="FolderDlg" Control_="Back" Event="NewDialog" Argument="WelcomeDlg" Condition="AI_INSTALL" Ordering="1"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Install" Event="EndDialog" Argument="Return" Condition="AI_INSTALL" Ordering="197"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Back" Event="NewDialog" Argument="FolderDlg" Condition="AI_INSTALL" Ordering="201"/>
    <ROW Dialog_="MaintenanceWelcomeDlg" Control_="Next" Event="NewDialog" Argument="MaintenanceTypeDlg" Condition="AI_MAINT" Ordering="99"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="[InstallMode]" Argument="Change" Condition="1" Ordering="100" MsiKey="MaintenanceTypeDlg#ChangeButton#[InstallMode]#Change#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="[Progress1]" Argument="[CtrlEvtChanging]" Condition="1" Ordering="200" MsiKey="MaintenanceTypeDlg#ChangeButton#[Progress1]#[CtrlEvtChanging]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="[Progress2]" Argument="[CtrlEvtchanges]" Condition="1" Ordering="300" MsiKey="MaintenanceTypeDlg#ChangeButton#[Progress2]#[CtrlEvtchanges]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="[AI_INSTALL_MODE]" Argument="Change" Condition="1" Ordering="400" MsiKey="MaintenanceTypeDlg#ChangeButton#[AI_INSTALL_MODE]#Change#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="[AI_CommitButton]" Argument="ButtonText_Install" Condition="1" Ordering="500" MsiKey="MaintenanceTypeDlg#ChangeButton#[AI_CommitButton]#ButtonText_Install#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="[InstallMode]" Argument="Remove" Condition="1" Ordering="100" MsiKey="MaintenanceTypeDlg#RemoveButton#[InstallMode]#Remove#1"/>
    <ROW Dialog_="CustomizeDlg" Control_="Next" Event="NewDialog" Argument="VerifyReadyDlg" Condition="AI_MAINT" Ordering="101"/>
    <ROW Dialog_="CustomizeDlg" Control_="Back" Event="NewDialog" Argument="MaintenanceTypeDlg" Condition="AI_MAINT" Ordering="1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="[Progress1]" Argument="[CtrlEvtRemoving]" Condition="1" Ordering="200" MsiKey="MaintenanceTypeDlg#RemoveButton#[Progress1]#[CtrlEvtRemoving]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="[Progress2]" Argument="[CtrlEvtremoves]" Condition="1" Ordering="300" MsiKey="MaintenanceTypeDlg#RemoveButton#[Progress2]#[CtrlEvtremoves]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="[AI_INSTALL_MODE]" Argument="Remove" Condition="1" Ordering="500" MsiKey="MaintenanceTypeDlg#RemoveButton#[AI_INSTALL_MODE]#Remove#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="[AI_CommitButton]" Argument="ButtonText_Remove" Condition="1" Ordering="600" MsiKey="MaintenanceTypeDlg#RemoveButton#[AI_CommitButton]#ButtonText_Remove#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="[InstallMode]" Argument="Repair" Condition="1" Ordering="100" MsiKey="MaintenanceTypeDlg#RepairButton#[InstallMode]#Repair#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="[Progress1]" Argument="[CtrlEvtRepairing]" Condition="1" Ordering="200" MsiKey="MaintenanceTypeDlg#RepairButton#[Progress1]#[CtrlEvtRepairing]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="[Progress2]" Argument="[CtrlEvtrepairs]" Condition="1" Ordering="300" MsiKey="MaintenanceTypeDlg#RepairButton#[Progress2]#[CtrlEvtrepairs]#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="[AI_INSTALL_MODE]" Argument="Repair" Condition="1" Ordering="500" MsiKey="MaintenanceTypeDlg#RepairButton#[AI_INSTALL_MODE]#Repair#1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="[AI_CommitButton]" Argument="ButtonText_Repair" Condition="1" Ordering="600" MsiKey="MaintenanceTypeDlg#RepairButton#[AI_CommitButton]#ButtonText_Repair#1"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Install" Event="EndDialog" Argument="Return" Condition="AI_MAINT" Ordering="198"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Back" Event="NewDialog" Argument="CustomizeDlg" Condition="AI_MAINT" Ordering="202"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="ChangeButton" Event="NewDialog" Argument="CustomizeDlg" Condition="AI_MAINT" Ordering="501"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="Back" Event="NewDialog" Argument="MaintenanceWelcomeDlg" Condition="AI_MAINT" Ordering="1"/>
    <ROW Dialog_="VerifyRemoveDlg" Control_="Remove" Event="EnableRollback" Argument="False" Condition="OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;" Ordering="500" MsiKey="VerifyRemoveDlg#Remove#EnableRollback#False#OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;"/>
    <ROW Dialog_="VerifyRemoveDlg" Control_="Remove" Event="Remove" Argument="ALL" Condition="OutOfDiskSpace &lt;&gt; 1" Ordering="100" MsiKey="VerifyRemoveDlg#Remove#Remove#All#OutOfDiskSpace &lt;&gt; 1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RemoveButton" Event="NewDialog" Argument="VerifyRemoveDlg" Condition="AI_MAINT AND InstallMode=&quot;Remove&quot;" Ordering="601"/>
    <ROW Dialog_="VerifyRemoveDlg" Control_="Back" Event="NewDialog" Argument="MaintenanceTypeDlg" Condition="AI_MAINT AND InstallMode=&quot;Remove&quot;" Ordering="1"/>
    <ROW Dialog_="VerifyRepairDlg" Control_="Repair" Event="EnableRollback" Argument="False" Condition="OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;" Ordering="600" MsiKey="VerifyRepairDlg#Repair#EnableRollback#False#OutOfDiskSpace = 1 AND OutOfNoRbDiskSpace = 0 AND PROMPTROLLBACKCOST=&quot;D&quot;"/>
    <ROW Dialog_="VerifyRepairDlg" Control_="Repair" Event="Reinstall" Argument="All" Condition="OutOfDiskSpace &lt;&gt; 1" Ordering="200" MsiKey="VerifyRepairDlg#Repair#Reinstall#All#OutOfDiskSpace &lt;&gt; 1"/>
    <ROW Dialog_="VerifyRepairDlg" Control_="Repair" Event="ReinstallMode" Argument="ecmus" Condition="OutOfDiskSpace &lt;&gt; 1" Ordering="100" MsiKey="VerifyRepairDlg#Repair#ReinstallMode#ecmus#OutOfDiskSpace &lt;&gt; 1"/>
    <ROW Dialog_="MaintenanceTypeDlg" Control_="RepairButton" Event="NewDialog" Argument="VerifyRepairDlg" Condition="AI_MAINT AND InstallMode=&quot;Repair&quot;" Ordering="601"/>
    <ROW Dialog_="VerifyRepairDlg" Control_="Back" Event="NewDialog" Argument="MaintenanceTypeDlg" Condition="AI_MAINT AND InstallMode=&quot;Repair&quot;" Ordering="1"/>
    <ROW Dialog_="VerifyRepairDlg" Control_="Repair" Event="EndDialog" Argument="Return" Condition="AI_MAINT AND InstallMode=&quot;Repair&quot;" Ordering="399" Options="1"/>
    <ROW Dialog_="VerifyRemoveDlg" Control_="Remove" Event="EndDialog" Argument="Return" Condition="AI_MAINT AND InstallMode=&quot;Remove&quot;" Ordering="299" Options="1"/>
    <ROW Dialog_="PatchWelcomeDlg" Control_="Next" Event="NewDialog" Argument="VerifyReadyDlg" Condition="AI_PATCH" Ordering="201"/>
    <ROW Dialog_="ResumeDlg" Control_="Install" Event="EndDialog" Argument="Return" Condition="AI_RESUME" Ordering="299"/>
    <ROW Dialog_="ExitDialog" Control_="Finish" Event="DoAction" Argument="AI_CleanPrereq" Condition="1" Ordering="301"/>
    <ROW Dialog_="FatalError" Control_="Finish" Event="DoAction" Argument="AI_CleanPrereq" Condition="1" Ordering="102"/>
    <ROW Dialog_="UserExit" Control_="Finish" Event="DoAction" Argument="AI_CleanPrereq" Condition="1" Ordering="101"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Install" Event="EndDialog" Argument="Return" Condition="AI_PATCH" Ordering="199"/>
    <ROW Dialog_="VerifyReadyDlg" Control_="Back" Event="NewDialog" Argument="PatchWelcomeDlg" Condition="AI_PATCH" Ordering="203"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiCustActComponent">
    <ROW Action="AI_CleanPrereq" Type="65" Source="Prereq.dll" Target="CleanPrereq" WithoutSeq="true"/>
    <ROW Action="AI_ConfigureChainer" Type="1" Source="Prereq.dll" Target="ConfigurePrereqLauncher"/>
    <ROW Action="AI_DOWNGRADE" Type="19" Target="4010"/>
    <ROW Action="AI_DownloadPrereq" Type="1" Source="Prereq.dll" Target="DownloadPrereq"/>
    <ROW Action="AI_DpiContentScale" Type="1" Source="aicustact.dll" Target="DpiContentScale"/>
    <ROW Action="AI_EnableDebugLog" Type="321" Source="aicustact.dll" Target="EnableDebugLog"/>
    <ROW Action="AI_ExtractPrereq" Type="65" Source="Prereq.dll" Target="ExtractPrereq"/>
    <ROW Action="AI_InstallModeCheck" Type="1" Source="aicustact.dll" Target="UpdateInstallMode" WithoutSeq="true"/>
    <ROW Action="AI_InstallPostPrerequisite" Type="1" Source="Prereq.dll" Target="InstallPostPrereq"/>
    <ROW Action="AI_InstallPrerequisite" Type="65" Source="Prereq.dll" Target="InstallPrereq"/>
    <ROW Action="AI_LaunchChainer" Type="3314" Source="AI_PREREQ_CHAINER"/>
    <ROW Action="AI_PREPARE_UPGRADE" Type="65" Source="aicustact.dll" Target="PrepareUpgrade"/>
    <ROW Action="AI_RESTORE_LOCATION" Type="65" Source="aicustact.dll" Target="RestoreLocation"/>
    <ROW Action="AI_ResolveKnownFolders" Type="1" Source="aicustact.dll" Target="AI_ResolveKnownFolders"/>
    <ROW Action="AI_SHOW_LOG" Type="65" Source="aicustact.dll" Target="LaunchLogFile" WithoutSeq="true"/>
    <ROW Action="AI_STORE_LOCATION" Type="51" Source="ARPINSTALLLOCATION" Target="[APPDIR]"/>
    <ROW Action="AI_VerifyPrereq" Type="1" Source="Prereq.dll" Target="VerifyPrereq"/>
    <ROW Action="SET_APPDIR" Type="307" Source="APPDIR" Target="[ProgramFilesFolder][Manufacturer]\[ProductName]"/>
    <ROW Action="SET_SHORTCUTDIR" Type="307" Source="SHORTCUTDIR" Target="[ProgramMenuFolder][ProductName]"/>
    <ROW Action="SET_TARGETDIR_TO_APPDIR" Type="51" Source="TARGETDIR" Target="[APPDIR]"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiInstExSeqComponent">
    <ROW Action="AI_DOWNGRADE" Condition="AI_NEWERPRODUCTFOUND AND (UILevel &lt;&gt; 5)" Sequence="210"/>
    <ROW Action="AI_RESTORE_LOCATION" Condition="APPDIR=&quot;&quot;" Sequence="749"/>
    <ROW Action="AI_STORE_LOCATION" Condition="(Not Installed) OR REINSTALL" Sequence="1501"/>
    <ROW Action="AI_PREPARE_UPGRADE" Condition="AI_UPGRADE=&quot;No&quot; AND (Not Installed)" Sequence="1399"/>
    <ROW Action="AI_ResolveKnownFolders" Sequence="53"/>
    <ROW Action="AI_EnableDebugLog" Sequence="51"/>
    <ROW Action="AI_ConfigureChainer" Condition="((UILevel = 2) OR (UILevel = 3)) AND (NOT UPGRADINGPRODUCTCODE)" Sequence="6598"/>
    <ROW Action="AI_LaunchChainer" Condition="AI_PREREQ_CHAINER AND (NOT UPGRADINGPRODUCTCODE)" Sequence="6599"/>
    <ROW Action="AI_VerifyPrereq" Sequence="1101"/>
    <ATTRIBUTE name="RegisterProduct" value="false"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiInstallUISequenceComponent">
    <ROW Action="AI_RESTORE_LOCATION" Condition="APPDIR=&quot;&quot;" Sequence="749"/>
    <ROW Action="AI_ResolveKnownFolders" Sequence="53"/>
    <ROW Action="AI_DpiContentScale" Sequence="52"/>
    <ROW Action="AI_EnableDebugLog" Sequence="51"/>
    <ROW Action="AI_DownloadPrereq" Sequence="1297"/>
    <ROW Action="AI_ExtractPrereq" Sequence="1298"/>
    <ROW Action="AI_InstallPrerequisite" Sequence="1299"/>
    <ROW Action="AI_InstallPostPrerequisite" Sequence="1301"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiLaunchConditionsComponent">
    <ROW Condition="(VersionNT &lt;&gt; 400)" Description="[ProductName] cannot be installed on [WindowsTypeNT40Display]." DescriptionLocId="AI.LaunchCondition.NoNT40" IsPredefined="true" Builds="DefaultBuild"/>
    <ROW Condition="(VersionNT &lt;&gt; 500)" Description="[ProductName] cannot be installed on [WindowsTypeNT50Display]." DescriptionLocId="AI.LaunchCondition.NoNT50" IsPredefined="true" Builds="DefaultBuild"/>
    <ROW Condition="(VersionNT64 OR ((VersionNT &lt;&gt; 501) OR (ServicePackLevel = 3))) AND ((VersionNT &lt;&gt; 502) OR (ServicePackLevel = 2))" Description="[ProductName] cannot be installed on [WindowsTypeNT5XDisplay]." DescriptionLocId="AI.LaunchCondition.NoNT5X" IsPredefined="true" Builds="DefaultBuild"/>
    <ROW Condition="VersionNT" Description="[ProductName] cannot be installed on [WindowsType9XDisplay]." DescriptionLocId="AI.LaunchCondition.No9X" IsPredefined="true" Builds="DefaultBuild"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiRegsComponent">
    <ROW Registry="$($applicationName)" Root="-1" Key="Software\Caphyon\Advanced Installer\Prereqs\[ProductCode]\[ProductVersion]" Name="$($applicationName)" Value="1" Component_="$($applicationName)"/>
    <ROW Registry="Path" Root="-1" Key="Software\[Manufacturer]\[ProductName]" Name="Path" Value="[APPDIR]" Component_="ProductInformation"/>
    <ROW Registry="Version" Root="-1" Key="Software\[Manufacturer]\[ProductName]" Name="Version" Value="[ProductVersion]" Component_="ProductInformation"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiThemeComponent">
    <ATTRIBUTE name="UsedTheme" value="classic"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.MsiUpgradeComponent">
    <ROW UpgradeCode="[|UpgradeCode]" VersionMin="0.0.1" VersionMax="[|ProductVersion]" Attributes="257" ActionProperty="OLDPRODUCTS"/>
    <ROW UpgradeCode="[|UpgradeCode]" VersionMin="[|ProductVersion]" Attributes="2" ActionProperty="AI_NEWERPRODUCTFOUND"/>
  </COMPONENT>
  <COMPONENT cid="caphyon.advinst.msicomp.PreReqComponent">
    <ROW PrereqKey="$($applicationName)" DisplayName="$($applicationName) $($applicationVersion)" SetupFileUrl="$($applicationName)_$($applicationVersion).exe" Location="0" ExactSize="0" Operator="1" Options="ip" TargetName="$($applicationName)_$($applicationVersion).exe" Feature="$($applicationName)"/>
    <ATTRIBUTE name="PrereqsOrder" value="$($applicationName)"/>
  </COMPONENT>
</DOCUMENT>
"@
$config4msi | Out-File -encoding ascii "$folderLoc\$($applicationName)_$($applicationVersion).aip"


# Wrap the EXE
$msbuild = "C:\Program Files (x86)\Caphyon\Advanced Installer 14.9\bin\x86\AdvancedInstaller.com"
$argumentz = @"
/build "$($folderLoc)\$($applicationName)_$($applicationVersion).aip"
"@

start-process -WindowStyle hidden $msbuild $argumentz -wait

# Remove all files

if(Test-Path "$folderLoc\$($applicationName)_$($applicationVersion).msi"){
	Get-ChildItem -Path  "$folderLoc" -Recurse -exclude "$($applicationName)_$($applicationVersion).msi" | Remove-Item -force -recurse
	Move-Item "$folderLoc\$($applicationName)_$($applicationVersion).msi" -Destination "$applicationPath\$($applicationName)_$($applicationVersion).msi"
}
#################################################################################################################################


# Prompt created app

if(Test-path "$applicationPath\$($applicationName)_$($applicationVersion).msi"){
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