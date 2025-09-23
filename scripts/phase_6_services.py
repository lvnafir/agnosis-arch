#!/usr/bin/env python3
"""Phase 6: Service Orchestration"""

import subprocess

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def main():
    print("Configure services: bluetooth, iwd, sshd, ly display manager")

    if ask_yes_no("Configure system services?"):
        try:
            # Enable and start critical services
            for service in ['bluetooth', 'iwd']:
                subprocess.run(['sudo', 'systemctl', 'enable', '--now', service], check=True)
                print(f"✅ Enabled and started: {service}")

            # Enable boot services
            subprocess.run(['sudo', 'systemctl', 'enable', 'sshd'], check=True)
            print("✅ Enabled for boot: sshd")

            # Enable display manager (starts in phase 8)
            subprocess.run(['sudo', 'systemctl', 'enable', 'ly'], check=True)
            print("✅ Display manager enabled for final launch")

            print("✅ Service configuration completed")
            return True

        except Exception as e:
            print(f"❌ Service configuration failed: {e}")
            return False
    else:
        print("Manual commands:")
        print("  sudo systemctl enable --now bluetooth iwd")
        print("  sudo systemctl enable sshd ly")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)