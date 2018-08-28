Clear-Host
function promptMessage($message, $type){
    switch($type)
    {
        'error' { Write-Host $message -ForegroundColor Red }
        'warning' { Write-Host $message -ForegroundColor Yellow }
        'success' { Write-Host $message -ForegroundColor Green }
        default { Write-Host $message }
    }
}

# Logging
$logPath = "$PSScriptRoot" # Log file folder in same location as the script
$logFileName = "AppMaker.log" # Log filename
$logFile = "$logPath\$logFileName" # Combine LPath and LFile to make one full path

if(!(Test-Path $logFile)){
	New-Item $logFile -Type file | Out-Null
}

function LogWrite {
    Param ([string]$logstring)
    $logTime = Get-Date -format "yyyy-MM-dd HH:mm:ss"
    $logText = $logTime + " - " + $logstring
    Add-content $logFile -value $logText
}

# Setup vars
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

Write-Host "===== AppMaker ====="
Write-Host " "
LogWrite "AppMaker started!"

# Select installer if multiple
$validFiles = @(Get-ChildItem "$($buildLocation)\*" -Include *.ps1,*.vbs,*.bat,*.exe,*.msi)
$validFilesCount = 0
$installerCount = 0

foreach ($validFile in $validFiles){
	Write-Host "[$($validFilesCount)] - $($validFile.name)"
	$validFilesCount++
}

if($validFilesCount -gt 0){
	while(!($installerID)){
		Write-Host " "
		$installerID = Read-Host 'Choose your installer'
	}
	
	# Set installer
	$appInstaller = $validFiles[$installerID].name
	$appExt = $validFiles[0].Extension
	LogWrite "Selected $($validFiles[$installerID])!"
}



# Check if installer is existing at all
if($appInstaller -and $installerCount -lt 2) {
    $appName = Read-Host 'App name? '
    $appVersion = Read-Host 'App version? '
 
    Clear-Host
	Write-Host "===== AppMaker ====="
	Write-Host " "
	
    while(!($appName)){
        $appName = Read-Host 'App name?'
    }
    while(!($appVersion)){
        $appVersion = Read-Host 'App version?'
    }
# Set installer type
if($appExt){
LogWrite "Found extension $appExt, setting installer type."
    switch($appExt)
    {
        '.ps1' { 
			$appInstType = "powershell.exe"
			$appInstParam = "-file $appInstaller"
		}
        '.vbs' { 
			$appInstType = "cscript.exe"
			$appInstParam = "$appInstaller"

		}
        '.msi' { 
			$appInstType = "msiexec.exe"
			$appInstOption = Read-Host 'Enter MSI options (example /silent /s)'
			$appInstParam = "/i $appInstaller $appInstOption"

		}
        '.exe' { 
			$appInstType = "$appInstaller"
			$appInstOption = Read-Host 'Enter EXE options (example /silent /s)'
			$appInstParam = "$appInstOption"

		}
		'.bat' { 
			$appInstType = "cmd.exe"
			$appInstParam = "/c $appInstaller"
		}
		'.bat' { 
			$appInstType = "cmd.exe"
			$appInstParam = "/c $appInstaller"
		}
    }
} else {
LogWrite "No file extension detected, exiting..."
Break
}
    Clear-Host
	Write-Host "===== AppMaker ====="
	Write-Host " "
    promptMessage "App name: $($appName)"
	LogWrite "App name: $($appName)"
    promptMessage "App version: $($appVersion)"
	LogWrite "App version: $($appVersion)"
	if($appInstOption){
    promptMessage "App options: $($appInstOption)"
	LogWrite "App options: $($appInstOption)"
	}
	Write-Host " "
    $continueMW = Read-Host 'Continue? [Y/N]'
} else {
    # Check if multiple installers exists
    if($installerCount -gt 1){
        promptMessage "Multiple installers found! We only need one..." "warning"
        promptMessage "Remove unwanted installers!" "warning"
		LogWrite "Multiple installers found! We only need one..."
		LogWrite "Remove unwanted installers!"
		Write-Host " "
    } else {
        promptMessage "No valid installer found!" "warning"
		LogWrite "No valid installer found!"
		Write-Host " "
    }
}



if($continueMW -contains "Y"){
Clear-Host
Write-Host "===== AppMaker ====="
Write-Host " "
promptMessage "Please wait while creating the EXE..." "success"
LogWrite "Preparing job"
Write-Host " "

# Get input for package
$applicationName = $appName.replace(" ","_")
$applicationVersion = $appVersion
$date = Get-Date -format "yyyy-MM-dd"

# Set folder for "complete"
$applicationPath = "$outputLocation\$applicationName\$applicationVersion - $date"

if(!(Test-path $applicationPath)){
LogWrite "Creating output folder - $applicationPath"
New-Item $applicationPath -Type Directory | Out-Null
} else {
LogWrite "Output folder already exists - $applicationPath"
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
ExecuteFile="$appInstType"
ExecuteParameters="$appInstParam"
;!@InstallEnd@!
"@
$config | Out-File -encoding ascii "$folderLoc\config.txt"
LogWrite "Creating config - $folderLoc\config.txt"

# Copy required sfx file to build folder
LogWrite "Copy sfx - $folderLoc\7zS.sfx"
Copy-Item "$templateLocation\7zS.sfx" -Destination "$folderLoc\7zS.sfx"

# Compress raw installer files
LogWrite "Compressing files"
if (-not (test-path "$templateLocation\7-Zip\7z.exe")) {throw "$templateLocation\7-Zip\7z.exe needed"}
set-alias sz "$templateLocation\7-Zip\7z.exe"
$zipFile = "temp.7z"
sz a -r "$folderLoc\$zipFile" "$folderLoc\*.*" | Out-Null

# Create EXE installer from compressed archive
LogWrite "Creating EXE file"
$command = @'
cmd.exe /C copy /b "$folderLoc\7zS.sfx" + "$folderLoc\config.txt" + "$folderLoc\$zipFile" "$folderLoc\$($applicationName)_$($applicationVersion).exe"
'@

Invoke-Expression -Command:$command | Out-Null

# Remove unnecessary files

if(Test-Path "$folderLoc\$($applicationName)_$($applicationVersion).exe"){
	LogWrite "Removing unwanted files"
	Get-ChildItem -Path  "$folderLoc" -Recurse -exclude "$($applicationName)_$($applicationVersion).exe" | Remove-Item -force -recurse
	LogWrite "Moving EXE to output folders"
	Move-Item "$folderLoc\$($applicationName)_$($applicationVersion).exe" -Destination "$applicationPath\$($applicationName)_$($applicationVersion).exe"
}
#################################################################################################################################


# If build is success prompt and exit..
if(Test-path "$applicationPath\$($applicationName)_$($applicationVersion).exe"){
	Clear-Host
	Write-Host "===== AppMaker ====="
	Write-Host " "
    promptMessage "The app $applicationName was created successfully!" "success"
	LogWrite "The app $applicationName was created successfully!"
	LogWrite "=================================================="
	Write-Host " "
    exit
} else {
	Clear-Host
	Write-Host "===== AppMaker ====="
	Write-Host " "
    promptMessage "ERROR! Something went wrong with the build - $applicationName could not be created!" "error"
	LogWrite "ERROR! Something went wrong with the build - $applicationName could not be created!"
	Write-Host " "
    exit
}

} else {
    promptMessage "Exiting..." "warning"
	LogWrite "Exiting..."
	Write-Host " "
}