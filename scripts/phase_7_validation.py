#!/usr/bin/env python3
"""Phase 7: System Validation - automatic validation"""

import subprocess
from pathlib import Path

def main():
    print("Performing comprehensive system validation...")
    failures = []

    # Critical files
    for file_path in [
        Path.home() / '.config' / 'hypr' / 'hyprland.conf',
        Path.home() / '.config' / 'waybar' / 'config',
        Path.home() / '.cache' / 'wal' / 'colors-waybar.css'
    ]:
        if not file_path.exists():
            failures.append(f"Missing: {file_path}")
        else:
            print(f"✅ Found: {file_path.name}")

    # Critical commands
    for command in ['hyprland', 'waybar', 'wal']:
        try:
            subprocess.run(['which', command], check=True, capture_output=True)
            print(f"✅ Command available: {command}")
        except:
            failures.append(f"Command missing: {command}")

    # Service states
    try:
        result = subprocess.run(['systemctl', 'is-enabled', 'ly'], capture_output=True)
        if result.returncode == 0:
            print("✅ Display manager enabled")
        else:
            failures.append("Display manager not enabled")
    except:
        failures.append("Could not check display manager")

    # Report results
    if failures:
        print("❌ Validation failed:")
        for failure in failures:
            print(f"  • {failure}")
        return False
    else:
        print("✅ System validation passed - ready for desktop launch")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)