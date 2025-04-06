import os
import csv


def extractDevicesByKeywords(pci_file,
                             output_csv,
                             vendor_id,
                             valid_keywords,
                             invalid_keywords,
                             invalid_device_ids=[]):

    with open(pci_file, 'r') as file:
        lines = file.readlines()

    vendor_section = False
    gpus = []

    for line in lines:
        if (line.startswith('#')):
            continue

        if (line.startswith(f"{vendor_id}")):
            vendor_section = True
            continue

        if (vendor_section and line.strip() and not line.startswith('\t')):
            break

        if (vendor_section and line.startswith('\t')
                and not line.startswith('\t\t')):
            parts = line.split('  ')

            if (len(parts) < 2):
                continue

            device_id = f"0x{parts[0].strip()}"
            if (any(invalid_id in device_id
                    for invalid_id in invalid_device_ids)):
                continue

            device_name = parts[1].strip()
            if (any(keyword in device_name for keyword in invalid_keywords)):
                continue

            if (any(keyword in device_name for keyword in valid_keywords)):
                gpus.append((device_name, device_id))

    if (os.path.exists(output_csv)):
        os.remove(output_csv)

    # Write the results to a CSV file
    with open(output_csv, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["GPU_Name", "PCI_Device_ID"])
        writer.writerows(gpus)

    print(f"Extraction complete. Results saved to {output_csv}")


nvidia_vendor_id = "10de"
nvidia_valid_keywords = [
    "GTX 6", "GTX 7", "GTX 9", "GTX 10", "RTX 20", "RTX 30", "RTX 40", "RTX 50"
]
nvidia_invalid_keywords = [
    "Engineering", "Sample", "Mac", "Plex", "M20", "NV37GL"
]

extractDevicesByKeywords('pci.ids', 'nvidia_gpus.csv', nvidia_vendor_id,
                         nvidia_valid_keywords, nvidia_invalid_keywords)

amd_vendor_id = "1002"
amd_valid_keywords = [
    "Navi", "Vega", "Raven", "Baffin", "Ellesmere", "Polaris", "Bristol",
    "Picasso", "Renoir", "Cezanne", "Van Gogh", "Rembrandt", "Strix Point",
    "Ridge"
]
amd_invalid_keywords = [
    "USB", "Switch", "Audio", "Coprocessor", "Duo", "W5700", "W5300M", "W5500",
    "W5600M", "W6500M", "W6600M", "W6800", "W6900", "W7500", "W7900",
    "Polaris 22", "Pro 5700"
]

extractDevicesByKeywords('pci.ids', 'amd_gpus.csv', amd_vendor_id,
                         amd_valid_keywords, amd_invalid_keywords)

intel_vendor_id = "8086"
intel_valid_keywords = ["Intel Graphics", "UHD", "HD", "Graphics"]
intel_invalid_keywords = [
    "Controller", "Accelerator", "Port", "Audio", "LE80578", "82845G/GL",
    "82852/855GM", "82915G/GV/GL/910GL", "Interface", "Broadwell-U",
    "IvyBridge", "Atom", "82854 GMCH Integrated Graphics Device",
    "Timna CPU Graphics", "HD Graphics 5600", "HD Graphics 5500",
    "HD Graphics 5300", "Iris Pro Graphics 6200", "HD Graphics 6000",
    "Iris Pro Graphics P6300", "Iris Graphics 6100"
]
intel_invalid_device_ids = ["0x1606"]

extractDevicesByKeywords('pci.ids', 'intel_gpus.csv', intel_vendor_id,
                         intel_valid_keywords, intel_invalid_keywords,
                         intel_invalid_device_ids)
