#!/usr/bin/env python3
"""Phase 3: Package Installation"""

import subprocess
from pathlib import Path

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def load_hardware_config():
    """Load hardware config from phase 2"""
    config = {'cpu_vendor': 'unknown', 'gpu_type': 'unknown', 'platform': 'desktop', 'vendor': 'generic'}
    config_file = Path('/tmp/agnosis-hardware.conf')

    if config_file.exists():
        for line in config_file.read_text().split('\n'):
            if '=' in line:
                key, value = line.strip().split('=', 1)
                if key.lower() in config:
                    config[key.lower()] = value
    return config

def get_package_files(hardware):
    """Get package files based on hardware"""
    repo_root = Path(__file__).parent.parent / 'packages'
    files = [repo_root / 'base-pacman.txt']  # Always install base

    # Hardware-specific additions
    hw_map = {
        'cpu_vendor': {'intel': 'intel-cpu-pacman.txt', 'amd': 'amd-cpu-pacman.txt'},
        'gpu_type': {'nvidia': 'nvidia-gpu-pacman.txt', 'amd': 'amd-gpu-pacman.txt', 'intel': 'intel-gpu-pacman.txt'},
        'platform': {'laptop': 'laptop-pacman.txt'},
        'vendor': {'thinkpad': 'thinkpad-pacman.txt'}
    }

    for hw_type, hw_files in hw_map.items():
        if hardware[hw_type] in hw_files:
            files.append(repo_root / hw_files[hardware[hw_type]])

    return [f for f in files if f.exists()]

def install_packages(package_files):
    """Install packages from files"""
    try:
        subprocess.run(['sudo', 'pacman', '-Sy'], check=True)

        for pkg_file in package_files:
            packages = []
            for line in pkg_file.read_text().split('\n'):
                line = line.strip()
                if line and not line.startswith('#'):
                    packages.append(line)

            if packages:
                cmd = ['sudo', 'pacman', '-S', '--needed', '--noconfirm'] + packages
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    print(f"Some packages from {pkg_file.name} failed: {result.stderr}")

        print("✅ Package installation completed")
        return True

    except Exception as e:
        print(f"❌ Package installation failed: {e}")
        return False

def main():
    hardware = load_hardware_config()
    package_files = get_package_files(hardware)

    print(f"Installing packages for: CPU={hardware['cpu_vendor']}, GPU={hardware['gpu_type']}, Platform={hardware['platform']}")
    print(f"Package files: {[f.name for f in package_files]}")

    if ask_yes_no("Install hardware-appropriate packages?"):
        return install_packages(package_files)
    else:
        print("Manual install: sudo pacman -S hyprland waybar kitty python-pywal")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)