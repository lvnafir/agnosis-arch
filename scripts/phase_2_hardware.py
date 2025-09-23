#!/usr/bin/env python3
"""Phase 2: Hardware Detection"""

import subprocess
from pathlib import Path

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def detect_hardware():
    """Detect hardware configuration"""
    hardware = {'cpu_vendor': 'unknown', 'gpu_type': 'unknown', 'platform': 'desktop', 'vendor': 'generic'}

    try:
        # CPU from /proc/cpuinfo
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read().lower()
            if 'intel' in cpuinfo: hardware['cpu_vendor'] = 'intel'
            elif 'amd' in cpuinfo: hardware['cpu_vendor'] = 'amd'

        # Platform from battery presence
        if Path('/sys/class/power_supply').exists():
            if any('BAT' in d.name.upper() for d in Path('/sys/class/power_supply').iterdir()):
                hardware['platform'] = 'laptop'

        # GPU from lspci
        result = subprocess.run(['lspci'], capture_output=True, text=True, timeout=3)
        if result.returncode == 0:
            lspci = result.stdout.lower()
            if 'nvidia' in lspci: hardware['gpu_type'] = 'nvidia'
            elif 'intel' in lspci and 'graphics' in lspci: hardware['gpu_type'] = 'intel'
            elif 'amd' in lspci or 'ati' in lspci: hardware['gpu_type'] = 'amd'

        # Vendor from DMI
        vendor_file = Path('/sys/class/dmi/id/sys_vendor')
        if vendor_file.exists():
            vendor = vendor_file.read_text().strip().lower()
            if 'lenovo' in vendor: hardware['vendor'] = 'thinkpad'
            elif 'dell' in vendor: hardware['vendor'] = 'dell'
            elif 'hp' in vendor: hardware['vendor'] = 'hp'
    except:
        pass

    return hardware

def save_config(hardware):
    """Save hardware config for other phases"""
    config = '\n'.join(f"{k.upper()}={v}" for k, v in hardware.items())
    Path('/tmp/agnosis-hardware.conf').write_text(config)
    Path('/tmp/agnosis-hardware.conf').chmod(0o600)

def main():
    hardware = detect_hardware()
    print(f"Detected: CPU={hardware['cpu_vendor']}, GPU={hardware['gpu_type']}, Platform={hardware['platform']}, Vendor={hardware['vendor']}")

    if ask_yes_no("Use this hardware configuration?"):
        save_config(hardware)
        print("✅ Hardware configuration saved")
        return True
    else:
        # Simple default fallback instead of complex manual entry
        default = {'cpu_vendor': 'unknown', 'gpu_type': 'unknown', 'platform': 'desktop', 'vendor': 'generic'}
        save_config(default)
        print("Using generic hardware configuration. Edit /tmp/agnosis-hardware.conf if needed.")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)