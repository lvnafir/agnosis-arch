#!/usr/bin/env python3
"""Phase 4: System Configuration"""

import shutil
from pathlib import Path

def ask_yes_no(prompt):
    while True:
        response = input(f"{prompt} (y/n): ").strip().lower()
        if response in ['y', 'yes']: return True
        elif response in ['n', 'no']: return False
        else: print("Please answer yes (y) or no (n).")

def main():
    config_source = Path(__file__).parent.parent / 'config'
    config_dest = Path.home() / '.config'

    print("Copy config files to ~/.config/, backup existing, set script permissions")

    if ask_yes_no("Proceed with configuration migration?"):
        if not config_source.exists():
            print("❌ Config directory not found")
            return False

        try:
            # Copy all config files
            for item in config_source.rglob('*'):
                if item.is_file():
                    rel_path = item.relative_to(config_source)
                    dest_path = config_dest / rel_path
                    dest_path.parent.mkdir(parents=True, exist_ok=True)

                    # Backup existing
                    if dest_path.exists():
                        shutil.copy2(dest_path, dest_path.with_suffix(dest_path.suffix + '.backup'))

                    shutil.copy2(item, dest_path)

            # Set script permissions
            for script in (config_dest / 'waybar').glob('*.sh'):
                script.chmod(0o755)

            print("✅ Configuration files migrated successfully")
            return True

        except Exception as e:
            print(f"❌ Configuration migration failed: {e}")
            return False
    else:
        print("Manual: cp -r config/* ~/.config/; chmod +x ~/.config/waybar/*.sh")
        return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if main() else 1)