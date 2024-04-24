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

Add-Type -AssemblyName PresentationFramework
$wshell = New-Object -ComObject wscript.shell;
$cSource = @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class Clicker
{
    // https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-input
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    { 
        public int        type; // 0 = INPUT_MOUSE
                                // 1 = INPUT_KEYBOARD
                                // 2 = INPUT_HARDWARE
        public MOUSEINPUT mi;
    }

    // https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-mouseinput
    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT
    {
        public int    dx;
        public int    dy;
        public int    mouseData;
        public int    dwFlags;
        public int    time;
        public IntPtr dwExtraInfo;
    }

    // This covers most use cases although complex mice may have additional buttons.
    // There are additional constants you can use for those cases, see the MSDN page.
    const int MOUSEEVENTF_MOVE       = 0x0001;
    const int MOUSEEVENTF_LEFTDOWN   = 0x0002;
    const int MOUSEEVENTF_LEFTUP     = 0x0004;
    const int MOUSEEVENTF_RIGHTDOWN  = 0x0008;
    const int MOUSEEVENTF_RIGHTUP    = 0x0010;
    const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    const int MOUSEEVENTF_MIDDLEUP   = 0x0040;
    const int MOUSEEVENTF_WHEEL      = 0x0080;
    const int MOUSEEVENTF_XDOWN      = 0x0100;
    const int MOUSEEVENTF_XUP        = 0x0200;
    const int MOUSEEVENTF_ABSOLUTE   = 0x8000;

    const int screen_length = 0x10000;

    // https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    extern static uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public static void LeftClickAtPoint(int x, int y)
    {
        // Move the mouse
        INPUT[] input = new INPUT[3];

        input[0].mi.dx = x * (65535 / System.Windows.Forms.Screen.PrimaryScreen.Bounds.Width);
        input[0].mi.dy = y * (65535 / System.Windows.Forms.Screen.PrimaryScreen.Bounds.Height);
        input[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;

        // Left mouse button down
        input[1].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;

        // Left mouse button up
        input[2].mi.dwFlags = MOUSEEVENTF_LEFTUP;

        SendInput(3, input, Marshal.SizeOf(input[0]));
    }
}
'@

Add-Type -TypeDefinition $cSource -ReferencedAssemblies System.Windows.Forms,System.Drawing

function enableUAC {
	$path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
	New-ItemProperty -Path $path -Name 'ConsentPromptBehaviorAdmin' -Value 5 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'ConsentPromptBehaviorUser' -Value 3 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'EnableInstallerDetection' -Value 1 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'EnableLUA' -Value 1 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'EnableVirtualization' -Value 1 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'PromptOnSecureDesktop' -Value 1 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'ValidateAdminCodeSignatures' -Value 0 -PropertyType DWORD -Force | Out-Null
	New-ItemProperty -Path $path -Name 'FilterAdministratorToken' -Value 0 -PropertyType DWORD -Force | Out-Null
}

function stressTest {
	choco install furmark heavyload hwinfo --yes
    New-Item -Path "C:\Program Files\HWiNFO64\" -Name "HWiNFO64.INI" -ItemType File
    Add-Content -Path "C:\Program Files\HWiNFO64\HWiNFO64.INI" -Value "[Settings]`rTheme=1`rAutoUpdateBetaDisable=1`rAutoUpdate=0`rSensorsOnly=1"
    Start-Process -WorkingDirectory "C:\Program Files\HWiNFO64\" -FilePath HWiNFO64.EXE
	Start-Sleep -Seconds 1
	[Clicker]::LeftClickAtPoint(1000, 600)
    Start-Sleep -Seconds 4
    [Clicker]::LeftClickAtPoint(1625, 850)
    Start-Sleep -Seconds 1
    [Clicker]::LeftClickAtPoint(1050, 440)
    Start-Sleep -Seconds 1
    $wshell.AppActivate('Save As')
    $wshell.SendKeys('stressTest')
    $wshell.SendKeys('~')
    Start-Process -WorkingDirectory "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark\" -FilePath FurMark.exe -ArgumentList "/width=1920 /height=1080 /msaa=4 /nogui /nomenubar /noscore /run_mode=2 /disable_catalyst_warning /max_frames=-1"
    Start-Process -WorkingDirectory "C:\Program Files\JAM Software\HeavyLoad\" -FilePath HeavyLoad.exe -ArgumentList "/start /cpu"
    Start-Sleep -Seconds 10
    [Clicker]::LeftClickAtPoint(1000, 1000)
}

function stopStressTest {
    Stop-Process -processname HWiNFO64
    Stop-Process -processname HeavyLoad
    Stop-Process -processname Furmark
}

function displayStressTest {
    Start-Process -FilePath "C:\Program Files\Mozilla Firefox\firefox.exe" -ArgumentList '--kiosk "https://logcharts-io.pages.dev/"'
    Start-Sleep 5
    [Clicker]::LeftClickAtPoint(850, 850)
    Start-Sleep 2
    $wshell.AppActivate('File Upload')
    $wshell.SendKeys('stressTest')
    $wshell.SendKeys('~')
    Start-Sleep 2
    [Clicker]::LeftClickAtPoint(1100, 950)
}


stressTest
[System.Windows.MessageBox]::Show("Finish stress test? `n(Closing will still stop the test) `n(Will open firefox kiosk window [ctrl + w to close])", "Finish Stress Test?", "Ok", "Information")
stopStressTest
displayStressTest
enableUAC
Write-Host "Uninstalling stress test programs."
choco uninstall gpu-z python furmark heavyload hwinfo hwinfo.install --yes