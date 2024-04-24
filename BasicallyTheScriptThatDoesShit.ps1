if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
	Start-Process powershell -Verb runAs
	Break
}

if (-NOT (Test-Connection -ComputerName www.archlinux.org -Quiet)) {
	Write-Host "No internet connection detected, retry after connecting."
	Write-Host "Note: Ethernet is recommended for setup, as there is no trace of your WiFi password or other sensitive information! (https://pureinfotech.com/share-internet-connection-windows-10/)"
	Write-Host "Pressing enter will reinitiate the script."
    pause
	Start-Process Powershell -Verb runAs
	Break
}

Write-Host Internet Connection: "$([char]0x1b)[92m$([char]8730)"
Write-Host Elevated Terminal: "$([char]0x1b)[92m$([char]8730)"
#The random bullshit is a checkmark, its stupid

$chipset# = Read-Host "`r 1: Intel `n 2: Ryzen/AMD `n 3: X99/Xeon `n Select One (1-3)"
$graphics# = Read-Host "`r 1: Intel Graphics `n 2: Radeon `n 3: Nvidia `n Select One (1-3)"
$amdDriverLocation = "C:\adrenaline-web.exe"
$x99DriverLocation = "C:\x99.zip"
$stressTest = 1
#Most likely just gonna create a seperate program in java so I can brush up on my skills, and use it to edit this script, as well as generate an iso through ntlite.
#Scratch that, still gonna create the java program, but it just sets a few true or false variables to disable checks and input

function chipsetDrivers {
	if ($chipset -eq 1) {
		Write-Host "Detected CPU Chipset: Intel-General"
		choco install intel-dsa --allowemptychecksum --yes
        #Does not acutally install the chipset drivers, it just installs the driver support assistant.
		#Im pretty sure if you restart it just automatically does it at some point but whatevs.
        #The DSA dosent have a command prompt interface, so we just have to wait as per Intel's words (https://www.intel.com/content/www/us/en/support/articles/000094418/software.html)
	} elseif ($chipset -eq 2) {
		Write-Host "Detected CPU Chipset: AMD-Ryzen-General"
		choco install amd-ryzen-chipset --allowemptychecksum --yes
	} elseif ($chipset -eq 3) {
		Write-Host "Detected CPU Chipset: Intel-X99-2011V3"
		Invoke-WebRequest -Uri "https://drive.google.com/uc?export=download&id=13s7D4xwr-Txrhfa6Ku0CCzwE_lSh2866" -OutFile $x99DriverLocation
		Expand-Archive $x99DriverLocation -DestinationPath "C:\x99"
		cmd /c "cd C:\x99 & start /w SetupChipset.exe -s -norestart"
        Remove-Item -Path "C:\x99" -Recurse
		Remove-Item -Path $x99DriverLocation -Recurse
	}
}

function graphicsDrivers {
	if ($graphics -eq 1) {
		Write-Host "Detected GPU Vendor: Intel"
		choco install intel-graphics-driver --allowemptychecksum --yes
	} elseif ($graphics -eq 2) {
		Write-Host "Detected GPU Vendor: AMD/ATI"
		Write-Host "The AMD/ATI Driver Installer is working but can be easily obsoleted, until i find out a fix, or unbreakable way to download the driver, radeon gpus will not be able to install drivers automatically"
		Write-Host "In order to access the most likely broken installer, go into the script configurator and tick the EXPERIMENTAL Driver Installer option"
		#curl.exe -e "https://www.amd.com/en/support/download/drivers.html" https://drivers.amd.com/drivers/installer/23.40/whql/amd-software-adrenalin-edition-24.3.1-minimalsetup-240320_web.exe -o $amdDriverLocation
	} elseif ($graphics -eq 3) {
		Write-Host "Detected GPU Vendor: NVIDIA"
		choco install nvidia-display-driver --allowemptychecksum --yes
	}
}

#Install chocolatey (https://chocolatey.org/about)
Write-Host "Starting chocolatey and common software install."
Set-ExecutionPolicy Unrestricted; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
#End of chocolatey install
refreshenv
choco install firefox steam epicgameslauncher winget	 --ignore-checksums --yes
refreshenv
choco install gpu-z python --yes
refreshenv
Write-Host "Finished chocolatey and common software install."

Write-Host "Detecting hardware."
$gpuzName = Get-ChildItem -Path "C:\ProgramData\chocolatey\lib\gpu-z\tools\*" -Include "*.exe" -Name
Start-Process -WorkingDirectory "C:\ProgramData\chocolatey\lib\gpu-z\tools\" -FilePath $gpuzName -ArgumentList "-dump gpuData.xml" -Wait
[xml]$gpuData = Get-Content "C:\ProgramData\chocolatey\lib\gpu-z\tools\gpuData.xml"
$gpuVendor = $gpuData.gpuz_dump.card.vendor
$cpuInfo = Get-CimInstance -ClassName Win32_Processor
$cpuSocket = $cpuInfo.SocketDesignation

switch ($cpuSocket) {
	AM5 {$chipset = 2}
	AM4 {$chipset = 2}
	"SOCKET 0" {$chipset = 3}
	Default {$chipset = 0}
}

switch ($gpuVendor) {
	Intel {$graphics = 1}
	AMD/ATI {$graphics = 2}
	NVIDIA {$graphics = 3}
	Default {$graphics = 0}
}

if (($chipset -eq 1) -or ($chipset -eq 2) -or ($chipset -eq 3)) {
	chipsetDrivers
}

if (($graphics -eq 1) -or ($graphics -eq 2) -or ($graphics -eq 3)) {
	graphicsDrivers
}

Write-Host "Finished driver install."
$stressTest = Read-Host "`r Start stress test? `n No (Will restart system): 0 `n Yes (Will restart and continute): 1"

if ($stressTest -eq 1) {
	Write-Host "Starting stress test procedure, restart queued."
	New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce -Force
	Set-Location HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce
	New-Itemproperty . RunStressTestScriptAfterRestart -propertytype String -value "powershell start-process powershell C:\Windows\Setup\TheAutomationScripts\StressTestScriptFinal.ps1 -verb runas"
	shutdown /r
} elseif ($stressTest -eq 0) {
	Write-Host "Closing script and Restarting"
	choco uninstall gpu-z python
	shutdown /r
}