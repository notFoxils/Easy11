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

$vendor# = Read-Host "`r 1: Intel `n 2: Ryzen/AMD `n 3: X99/Xeon `n Select One (1-3)"
$graphics# = Read-Host "`r 1: Intel Graphics `n 2: Radeon `n 3: Nvidia `n Select One (1-3)"
$amdDriverLocation = "C:\adrenaline.exe"
$x99DriverLocation = "C:\x99.zip"
$stressTest = 1
#Most likely just gonna create a seperate program in java so I can brush up on my skills, and use it to edit this script, as well as generate an iso through ntlite.
#Scratch that, still gonna create the java program, but it just sets a few true or false variables to disable checks and input

function chipsetDrivers {
	if ($vendor -eq 1) {
		Write-Host "Detected CPU Vendor: Intel"
		choco install intel-dsa --allowemptychecksum --yes
        #Does not acutally install the chipset drivers, it just installs the driver support assistant.
		#Im pretty sure if you restart it just automatically does it at some point but whatevs.
        #The DSA dosent have a command prompt interface, so we just have to wait as per Intel's words (https://www.intel.com/content/www/us/en/support/articles/000094418/software.html)
	} elseif ($vendor -eq 2) {
		Write-Host "Detected CPU Vendor: AMD"
		choco install amd-ryzen-chipset --allowemptychecksum --yes
	} elseif ($vendor -eq 3) {
		Write-Host "Detected CPU Vendor: Intel (X99/2011V3)"
		Invoke-WebRequest -Uri "https://drive.google.com/uc?export=download&id=13s7D4xwr-Txrhfa6Ku0CCzwE_lSh2866" -OutFile $x99DriverLocation
		Expand-Archive $x99DriverLocation -DestinationPath "C:\x99"
		Start-Process -WorkingDirectory "C:\x99\SetupChipset.exe" -ArgumentList "-s -norestart" -Wait
        Remove-Item -Path "C:\x99" -Recurse
		Remove-Item -Path $x99DriverLocation -Recurse
	}
}

function graphicsDrivers {
	if ($graphics -eq 1) {
		Write-Host "Detected GPU : Intel"
		choco install intel-graphics-driver --allowemptychecksum --yes
	} elseif ($graphics -eq 2) {
		Write-Host "Detected GPU: AMD/ATI Non-Legacy"
		#Big thanks to nunodxxd for making the script to grab the driver so I dont have to
		$currentDriverLink = (curl.exe https://raw.githubusercontent.com/nunodxxd/AMD-Software-Adrenalin/main/configs/link_full.txt)
		curl.exe -e "https://www.amd.com/en/support/download/drivers.html" $currentDriverLink -o $amdDriverLocation
		Start-Process $amdDriverLocation -ArgumentList "-INSTALL"
	} elseif ($graphics -eq 2) {
		Write-Host "Detected GPU: AMD/ATI Legacy/Polaris"
		#Big thanks to nunodxxd for making the script to grab the driver so I dont have to
		#this one is for the Polaris series cards which dont use latest driver because they are now legacy
		$currentDriverLink = (curl.exe https://raw.githubusercontent.com/nunodxxd/AMD-Software-Adrenalin/24.3.1/configs/link_full.txt)
		curl.exe -e "https://www.amd.com/en/support/download/drivers.html" $currentDriverLink -o $amdDriverLocation
		Start-Process $amdDriverLocation -ArgumentList "-INSTALL"	
	} elseif ($graphics -eq 3) {
		Write-Host "Detected GPU: NVIDIA"
		choco install nvidia-display-driver --allowemptychecksum --yes
	}
}

function installChocolatey {
	#https://chocolatey.org/about
	Write-Host "Starting chocolatey install."
	Set-ExecutionPolicy Unrestricted; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
	$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
	Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
	Write-Host "Finished chocolatey install."
	refreshenv
}

function installSoftware {
	Write-Host "Installing software install"
	choco install firefox steam epicgameslauncher winget gpu-z --ignore-checksums --yes
	Write-Host "Finished software install"
	refreshenv
}

function installDrivers {
	Write-Host "Detecting hardware."
	Write-Host "Using GPU-Z to grab GPU info."
	$gpuzName = Get-ChildItem -Path "C:\ProgramData\chocolatey\lib\gpu-z\tools\*" -Include "*.exe" -Name
	Start-Process -WorkingDirectory "C:\ProgramData\chocolatey\lib\gpu-z\tools\" -FilePath $gpuzName -ArgumentList "-dump gpuData.xml" -Wait
	[xml]$gpuData = Get-Content "C:\ProgramData\chocolatey\lib\gpu-z\tools\gpuData.xml"
	$gpuVendor = $gpuData.gpuz_dump.card.vendor
	Write-Host "Detecting processor socket."
	$cpuInfo = Get-CimInstance -ClassName Win32_Processor
	$cpuSocket = $cpuInfo.SocketDesignation

	switch ($cpuSocket) {
		AM5 {$vendor = 2}
		AM4 {$vendor = 2}
		"SOCKET 0" {$vendor = 3}
		Default {$vendor = 0}
	}

	switch ($gpuVendor) {
		Intel {$graphics = 1}
		AMD/ATI {
			#Check for Polaris
			if ($gpuData.deviceid -eq "67DF") {
				$graphics = 3
				break
			}
			$graphics = 2
		}
		NVIDIA {$graphics = 4}
		Default {$graphics = 0}
	}

	if ($vendor -ne 0) {
		chipsetDrivers
	}

	if ($graphics -ne 0) {
		graphicsDrivers
	}

	Write-Host "Finished driver install."
}

function stressTestInit {
	$stressTest = Read-Host "`r Start stress test? `n No (Will restart system): 0 `n Yes (Will restart and continute): 1"

	if ($stressTest -eq 1) {
		Write-Host "Starting stress test procedure, restart queued."
		New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce -Force
		Set-Location HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce
		New-Itemproperty . RunStressTestScriptAfterRestart -PropertyType String -Value "Powershell Start-Process Powershell C:\Windows\Setup\TheAutomationScripts\StressTestScriptFinal.ps1 -Verb runas"
		shutdown /r
	} elseif ($stressTest -eq 0) {
		Write-Host "Closing script and restarting"
		choco uninstall gpu-z --yes
		shutdown /r
	}
}
