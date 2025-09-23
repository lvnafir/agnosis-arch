#!/usr/bin/env python3
"""Phase 8: Desktop Launch - final step"""

import subprocess
import time

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def main():
    print("Final step: Start ly display manager and launch Hyprland desktop")

    if ask_yes_no("Launch desktop environment now?"):
        try:
            subprocess.run(['sudo', 'systemctl', 'start', 'ly'], check=True)
            time.sleep(2)

            result = subprocess.run(['systemctl', 'is-active', 'ly'], capture_output=True)
            if result.returncode == 0:
                print("✅ Display manager started successfully!")
                print("✅ Bootstrap completed - desktop environment is launching")
                print("Log in through the display manager to access your Hyprland desktop")
                return True
            else:
                print("❌ Display manager failed to start")
                print("Check logs: journalctl -u ly")
                return False

        except Exception as e:
            print(f"❌ Failed to start display manager: {e}")
            return False
    else:
        print("Desktop launch skipped.")
        print("Manual command: sudo systemctl start ly")
        print("✅ Bootstrap completed successfully!")
        print("Your system is configured and ready for manual launch")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)