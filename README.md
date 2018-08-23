# AppMaker

AppMaker is a tool to create .exe files from "script installers". This may be a Batch, VBs or Powershell script to install exe's or msi's. AppMaker will take all files and folders and create one EXE file.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

What you'll need to run AppMaker

```
Powershell 5.1
```

## How to use

First time? Run AppMaker_CLI.ps1, this will create two empty neccessary folders.

To use AppMaker, you'll need to drop your installer script + resources in the folder "DropFilesHere" then continue below.

GUI
```
Run AppMaker.ps1
Enter a name for your files (for example "Mozilla Firefox")
Choose installer, this could be either .bat, .vbs or .ps1.
Enter version (for example "1.33.7")
Click "Create"
```
As soon as you click create AppMaker starts build your application. Whenever the job is done you'll be prompted with a success message followed by the output folder.

CLI
```
Run AppMaker_CLI.ps1
Choose installer by enter the number next to the file name. The installer could be either .bat, .vbs or .ps1.
Enter a name for your files (for example "Mozilla Firefox")
Enter version (for example "1.33.7")
Confirm by enter (Y/y).
```
AppMaker will now start to build your application. Whenever the job is done you'll be prompted with a success message.

All your created apps will be found in the folder "COMPLETE".

## Built With

* [7-ZIP](https://www.7-zip.org/7z.html) - SFX to actually create the .EXE file


## Authors

* **Tommy Carlsson** - *From scratch..* - [Source011](https://github.com/source011)
