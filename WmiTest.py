import glob
import requests
import subprocess
import os
import sys
import wmi
import re
from zipfile import ZipFile

w = wmi.WMI()


def parsePnpDeviceId(deviceId):
    pattern = r"^(?P<BusType>[A-Za-z0-9]+)\\VEN_(?P<VendorID>[A-F0-9]{4})&DEV_(?P<DeviceID>[A-F0-9]{4})(?:&SUBSYS_(?P<SubsystemID>[A-F0-9]{8}))?(?:&REV_(?P<RevisionID>[A-F0-9]{2}))?\\(?P<Rest>.*)$"
    match = re.match(pattern, deviceId)

    if match:
        result = match.groupdict()
        return result
    else:
        return None


# Use PNPDeviceID
# Along with with a file of sorts that lists all the compatible device-ids
# Then use the manufacturer id to decide AMD/Nvidia/Intel
for videoController in w.Win32_VideoController():
    pnpDeviceId = parsePnpDeviceId(videoController.PNPDeviceID)

    if (not pnpDeviceId):
        continue

    if (pnpDeviceId["BusType"] != "PCI"):
        continue

    print(pnpDeviceId["DeviceID"])

sys.exit()

for a in w.Win32_BaseBoard():
    # Use 'Product' property to find chipset
    # Specifically search for a substring of lets say "B450", inside "ASRock B450m/ac R2.0"
    # Then direct to installAmdChipset
    print(a)


def downloadFile(url, destinationDirectory, fileName, referrer=None):
    try:
        headers = {
            'User-Agent':
            'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.76 Safari/537.36',
            "Upgrade-Insecure-Requests": "1",
            "DNT": "1",
            "Accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
            "Accept-Encoding": "gzip, deflate",
            "Referer": referrer
        }

        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()

        downloadDestination = os.path.join(destinationDirectory, fileName)

        with open(downloadDestination, 'wb') as file:
            for downloadChunk in response.iter_content(chunk_size=8192):
                file.write(downloadChunk)

            file.close()
            return downloadDestination

        return None
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        print(f"When downloading from: {url}")
        return None
    except OSError as e:
        print(f"Error: {e}")
        print(f"When downloading file to {destinationDirectory}/{fileName}")
        return None


AMD_CHIPSET_DOWNLOAD_LINK_SOURCE = "https://raw.githubusercontent.com/notFoxils/AMD-Chipset-Drivers/main/configs/link.txt"


def getAmdChipsetDownloadLink():
    try:
        response = requests.get(AMD_CHIPSET_DOWNLOAD_LINK_SOURCE)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        print(
            f"When pulling the AMD Chipset Download Link from: {AMD_CHIPSET_DOWNLOAD_LINK_SOURCE}"
        )
        sys.exit()

    return response.text.strip()


AMD_CHIPSET_DOWNLOAD_LINK = getAmdChipsetDownloadLink()
INTEL_CHIPSET_DOWNLOAD_LINK = "https://downloadmirror.intel.com/843223/SetupChipset.exe"
X99_INTEL_CHIPSET_DOWNLOAD_LINK = "https://drive.google.com/uc?export=download&id=13s7D4xwr-Txrhfa6Ku0CCzwE_lSh2866"

CHIPSET_DRIVER_DOWNLOAD_DIRECTORY = "C:\\Windows\\Temp"
CHIPSET_DRIVER_FILENAME = "chipsetDriver"

X99_INTEL_CHIPSET_DRIVER_EXTRACT_DIRECTORY = os.path.join(
    CHIPSET_DRIVER_DOWNLOAD_DIRECTORY, CHIPSET_DRIVER_FILENAME)

AMD_CHIPSET_DRIVER_ARGS = []
INTEL_CHIPSET_DRIVER_ARGS = []
X99_INTEL_CHIPSET_DRIVER_ARGS = []


def installAmdChipset():
    # Support for all Ryzen chipsets
    chipsetDriver = downloadFile(AMD_CHIPSET_DOWNLOAD_LINK,
                                 CHIPSET_DRIVER_DOWNLOAD_DIRECTORY,
                                 CHIPSET_DRIVER_FILENAME + ".exe",
                                 "https://www.amd.com/en.html")
    if (chipsetDriver == None):
        print("Failed to download AMD Chipset Driver")
        print(f"Chipset Download Link: {AMD_CHIPSET_DOWNLOAD_LINK}")
        return False

    subprocess.run([chipsetDriver, *AMD_CHIPSET_DRIVER_ARGS])


def installIntelChipset():
    # This has support for Skylake (Gen6) onwards
    # This isnt really a chipset "driver", its more an identifier-installer
    # It supplies Windows Update with more info about the chipset-hardware so that Windows Update can install drivers for the chipset from Microsoft's database
    # The identifiers are rarely needed, useless really, but better safe than sorry and theres no real way of actually installing the chipset drivers so this is the next best thing
    chipsetDriver = downloadFile(INTEL_CHIPSET_DOWNLOAD_LINK,
                                 CHIPSET_DRIVER_DOWNLOAD_DIRECTORY,
                                 CHIPSET_DRIVER_FILENAME + ".exe")
    if (chipsetDriver == None):
        print("Failed to download Intel Chipset Driver")
        print(f"Chipset Download Link: {INTEL_CHIPSET_DOWNLOAD_LINK}")
        return False

    subprocess.run([chipsetDriver, *INTEL_CHIPSET_DRIVER_ARGS])


def installX99IntelChipset():
    # This one is a bit sped-ecial, I download the driver direct from Machinist's... Google Drive
    # Nothing wrong with the driver, just a bit weird on the source
    chipsetDriverZipped = downloadFile(X99_INTEL_CHIPSET_DOWNLOAD_LINK,
                                       CHIPSET_DRIVER_DOWNLOAD_DIRECTORY,
                                       CHIPSET_DRIVER_FILENAME + ".zip")
    if (chipsetDriverZipped == None):
        print("Failed to download Intel-X99 Chipset Driver")
        print(f"Chipset Download Link: {X99_INTEL_CHIPSET_DOWNLOAD_LINK}")
        return False

    try:
        with ZipFile(chipsetDriverZipped, "r") as zippedChipsetDriver:
            zippedChipsetDriver.extractall(
                path=X99_INTEL_CHIPSET_DRIVER_EXTRACT_DIRECTORY)
            zippedChipsetDriver.close()

    except OSError:
        print("Failed to extract Intel-X99 Chipset Driver")
        print(f"Zipped Chipset Driver: {chipsetDriverZipped}")
        return False

    chipsetDriver = os.path.join(X99_INTEL_CHIPSET_DRIVER_EXTRACT_DIRECTORY,
                                 "SetupChipset.exe")

    subprocess.run([chipsetDriver, *X99_INTEL_CHIPSET_DRIVER_ARGS])

    for file in glob.glob(
            os.path.join(CHIPSET_DRIVER_DOWNLOAD_DIRECTORY,
                         CHIPSET_DRIVER_FILENAME + ".*")):
        os.remove(file)
