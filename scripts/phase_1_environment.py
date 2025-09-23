#!/usr/bin/env python3
"""Phase 1: Environment Validation"""

import os
import sys
import subprocess
from pathlib import Path

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def validate_environment():
    """Check system requirements"""
    checks = [
        (Path('/etc/arch-release').exists(), "Arch Linux"),
        (subprocess.run(['sudo', '-n', 'true'], capture_output=True).returncode == 0, "Sudo access"),
        (all((Path(__file__).parent.parent / d).exists() for d in ['scripts', 'config']), "Repository structure"),
        (subprocess.run(['ping', '-c1', '8.8.8.8'], capture_output=True, timeout=3).returncode == 0, "Internet"),
        (os.statvfs('/').f_frsize * os.statvfs('/').f_bavail > 2048*1024*1024, "Disk space (2GB+)")
    ]

    for check, name in checks:
        if not check:
            print(f"❌ {name} - failed")
            return False
        print(f"✅ {name}")
    return True

def main():
    print("Environment validation checks: Arch Linux, sudo, repo structure, internet, disk space")

    if ask_yes_no("Run validation?"):
        return validate_environment()
    else:
        print("Manual checklist: cat /etc/arch-release; sudo -v; ping -c1 archlinux.org; df -h")
        return True

if __name__ == "__main__":
    sys.exit(0 if main() else 1)