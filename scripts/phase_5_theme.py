#!/usr/bin/env python3
"""Phase 5: Theme Initialization - CRITICAL for waybar functionality"""

import subprocess
from pathlib import Path

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def main():
    print("Initialize pywal theme system (creates colors-waybar.css for waybar)")

    if ask_yes_no("Initialize theme system?"):
        wallpaper_dir = Path.home() / 'Pictures' / 'wallpapers'
        if not wallpaper_dir.exists():
            print("❌ Wallpapers directory not found")
            return False

        wallpapers = list(wallpaper_dir.glob('*.jpg')) + list(wallpaper_dir.glob('*.png'))
        if not wallpapers:
            print("❌ No wallpapers found")
            return False

        try:
            subprocess.run(['wal', '-i', str(wallpapers[0])], check=True)

            waybar_colors = Path.home() / '.cache' / 'wal' / 'colors-waybar.css'
            if waybar_colors.exists():
                print("✅ Theme system initialized - waybar colors created")
                return True
            else:
                print("❌ Waybar colors not created - waybar will fail")
                return False

        except Exception as e:
            print(f"❌ Theme initialization failed: {e}")
            return False
    else:
        print("⚠️  WARNING: waybar will fail without pywal colors!")
        print("Manual fix: wal -i ~/Pictures/wallpapers/[image]")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)