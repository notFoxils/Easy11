if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" +$myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

if (-NOT (Test-Connection -ComputerName www.archlinux.org -Quiet)) {
    Write-Host "No internet connection detected, retry after connecting"
    Write-Host "Note: Ethernet is recommended for setup, as there is no trace of your WiFi password or other sensitive information! (https://pureinfotech.com/share-internet-connection-windows-10/)"
    Write-Host "Pressing enter will reinitiate the script"
    pause
    Start-Process Powershell -Verb runAs
    Break
}

Write-Host Internet Connection: "$([char]0x1b)[92m$([char]8730)"
Write-Host Elevated Terminal: "$([char]0x1b)[92m$([char]8730)"
#The random bullshit is a checkmark, its stupid

$predefinedCPUVendor
$predefinedGPUVendor
$debug = $false

function installChocolatey {
    #https://chocolatey.org/about
    Write-Host "Starting chocolatey install" 

    #Following is from https://docs.chocolatey.org/en-us/choco/setup
    Set-ExecutionPolicy Unrestricted; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    #This imports the refreshenv command so that choco can initialize without relaunching powershell
    $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

    Write-Host "Finished chocolatey install"
    refreshenv

    installSoftware
}

function installSoftware {
    Write-Host "Installing software install"

    choco install firefox steam epicgameslauncher winget gpu-z --ignore-checksums --yes

    Write-Host "Finished software install"
}

function chipsetDrivers($vendor = -1) {
    Write-Host "Starting CPU chipset installation"

    $chipsetDriverLocation = "C:\chipset"

    if ($debug) {
        Write-Host $vendor
    } else if ($vendor -eq 1) {
        Write-Host "Detected CPU Vendor: Intel"

        Invoke-WebRequest -Uri "https://downloadmirror.intel.com/843223/SetupChipset.exe" -OutFile $chipsetDriverLocation
    } elseif ($vendor -eq 2) {
        Write-Host "Detected CPU Vendor: AMD"

        choco install amd-ryzen-chipset --yes
    } elseif ($vendor -eq 3) {
        Write-Host "Detected CPU Vendor: Intel (X99/2011V3)"

        $zippedDriver = ( $chipsetDriverLocation + ".zip" )

        Invoke-WebRequest -Uri "https://drive.google.com/uc?export=download&id=13s7D4xwr-Txrhfa6Ku0CCzwE_lSh2866" -OutFile ( $chipsetDriverLocation + ".zip" )
        Expand-Archive ( $chipsetDriverLocation + ".zip"  ) -DestinationPath $chipsetDriverLocation

        Start-Process -WorkingDirectory $chipsetDriverLocation + "/SetupChipset.exe" -ArgumentList "-s -norestart" -Wait

        Remove-Item -Path ( $chipsetDriverLocation + ".zip" ) -Recurse
    } else {
        Write-Host "Could not detect a chipset/chipset vendor"
        return
    }

    Remove-Item -Path $chipsetDriverLocation -Recurse
    Write-Host "Finished CPU chipset install process, moving to GPU driver installation"
}

function downloadAmdChipset($socket = "AM5", $boardLine = "b550") {
    $chipsetDriverLink = ( "https://www.amd.com/en/support/downloads/drivers.html/chipsets/" + $socket + "/" + $boardLine + ".html" )
}

function graphicsDrivers($graphics = -1) {
    Write-Host "Starting GPU driver installation"

    if ($debug) {
        Write-Host $graphics
    } elseif ($graphics -eq 1) {
        Write-Host "Detected GPU : Intel"

        choco install intel-graphics-driver --yes
    } elseif ($graphics -eq 2) {
        #Big thanks to nunodxxd for making the script to grab the driver so I dont have to
        $adrenalineDriverLink = (curl.exe "https://raw.githubusercontent.com/nunodxxd/AMD-Software-Adrenalin/main/configs/link_full.txt")
        $amdDriverLocation = "C:\adrenaline.exe"

        Write-Host "Detected GPU: AMD/ATI Non-Legacy"

        curl.exe -e "https://www.amd.com/en/support/download/drivers.html" $AdrenalineDriverLink -o $amdDriverLocation
        Start-Process $amdDriverLocation -ArgumentList "-INSTALL"
    } elseif ($graphics -eq 3) {
        #Big thanks to nunodxxd for making the script to grab the driver so I dont have to
        #This one is for the Polaris series cards which dont use latest driver because they are now legacy
        $AdrenalineDriverLink = (curl.exe "https://raw.githubusercontent.com/nunodxxd/AMD-Software-Adrenalin/24.3.1/configs/link_full.txt")

        Write-Host "Detected GPU: AMD/ATI Legacy/Polaris"

        curl.exe -e "https://www.amd.com/en/support/download/drivers.html" $AdrenalineDriverLink -o $amdDriverLocation
        Start-Process $amdDriverLocation -ArgumentList "-INSTALL" } elseif ($graphics -eq 4) {
        Write-Host "Detected GPU: NVIDIA"

        choco install nvidia-display-driver --yes
    } else {
        Write-Host "GPU vendor cannot be detected or vendor detection has been skipped"
    }

    Write-Host "Finished GPU driver install process, moving to stress testing initialization"
}

function recognizeHardware {
    $gpuzName = Get-ChildItem -Path "C:\ProgramData\chocolatey\lib\gpu-z\tools\*" -Include "*.exe" -Name
    $gpuData
    $gpuVendor
    $cpuInfo
    $cpuSocket
    $graphics
    $vendor

    Write-Host "Detecting hardware"
    Write-Host "Using GPU-Z to grab GPU info"

    Start-Process -WorkingDirectory "C:\ProgramData\chocolatey\lib\gpu-z\tools\" -FilePath $gpuzName -ArgumentList "-dump gpuData.xml" -Wait
    [xml]$gpuData = Get-Content "C:\ProgramData\chocolatey\lib\gpu-z\tools\gpuData.xml"
    $gpuVendor = $gpuData.gpuz_dump.card.vendor

    Write-Host "Detecting processor socket"

    $cpuInfo = Get-CimInstance -ClassName Win32_Processor
    $cpuSocket = $cpuInfo.SocketDesignation

    switch ($cpuSocket) {
        AM5 {$vendor = 2}
        AM4 {$vendor = 2}
        "SOCKET 0" {$vendor = 3}
        Default {$vendor = 0}
    }

    switch ($gpuVendor) {
        Intel { $graphics = 1 }
        AMD/ATI {
            # Check for Polaris
            # Uses the PCI device id which matches from the 450 to 590 and the in betweens

            if ($gpuData.deviceid -eq "67DF" -or $gpuData.deviceid -eq "67EF" -or $gpuData.deviceid -eq "699F" -or $gpuData.deviceid -eq "67FF") {
                $graphics = 3
                break
            }

            $graphics = 2
        }
        NVIDIA {$graphics = 4}
        Default {$graphics = 0}
    }

    $array = $vendor, $graphics

    return $array
}

function stressTestInit {
    $stressTest = Read-Host "`rStart stress test? `nNo (Will restart system): 0 `nYes (Will restart and continute): 1`n"

    if ($stressTest -eq 1) {
        Write-Host "Starting stress test procedure, restart queued"

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


function main {
    installChocolatey
    installSoftware
    $graphicsAndChipsetDetection = recognizeHardware
    chipsetDrivers -vendor $graphicsAndChipsetDetection[6] #dark evil wizard magic adds 6 " " to the array id rather not question it
    graphicsDrivers -graphics $graphicsAndChipsetDetection[7]
    Write-Host "Finished driver install"
    stressTestInit
}

main
