#!/usr/bin/env python3
"""
Waybar-CAVA Setup Script
Automates the installation and configuration of native CAVA audio visualizer for Waybar
"""

import os
import sys
import json
import subprocess
import shutil
import urllib.request
from pathlib import Path
from typing import Dict, Any, Optional

class WaybarCavaSetup:
    def __init__(self):
        self.home = Path.home()
        self.waybar_dir = self.home / ".config" / "waybar"
        self.cava_dir = self.home / ".config" / "cava"
        self.created_files = []  # Track files created during setup
        self.backup_path = None  # Track backup file path
        self.removed_regular_waybar = False  # Track if we removed regular waybar
        
    def log(self, message: str, level: str = "INFO"):
        """Simple logging with colors"""
        colors = {
            "INFO": "\033[92m",    # Green
            "WARN": "\033[93m",    # Yellow
            "ERROR": "\033[91m",   # Red
            "RESET": "\033[0m"     # Reset
        }
        print(f"{colors.get(level, '')}{level}: {message}{colors['RESET']}")
    
    def run_command(self, cmd: str, capture_output: bool = True) -> tuple[bool, str]:
        """Execute shell command and return success status and output"""
        try:
            result = subprocess.run(
                cmd, shell=True, 
                capture_output=capture_output, 
                text=True, 
                check=True
            )
            return True, result.stdout.strip() if capture_output else ""
        except subprocess.CalledProcessError as e:
            error_msg = e.stderr.strip() if e.stderr else str(e)
            return False, error_msg
    
    def install_cava(self) -> bool:
        """Install CAVA package using pacman"""
        self.log("Installing CAVA package...")
        
        success, output = self.run_command("sudo pacman -S --noconfirm cava", capture_output=True)
        if success:
            self.log("CAVA installed successfully")
            return True
        else:
            self.log(f"Failed to install CAVA: {output}", "ERROR")
            return False
    
    def remove_regular_waybar(self) -> bool:
        """Remove regular waybar package if installed"""
        self.log("Checking for regular waybar package...")
        
        # Check if regular waybar is installed
        success, _ = self.run_command("pacman -Q waybar")
        if not success:
            self.log("Regular waybar is not installed")
            return True
        
        self.log("Regular waybar found. Removing before installing waybar-cava...")
        success, output = self.run_command("sudo pacman -R --noconfirm waybar", capture_output=True)
        if success:
            self.log("Regular waybar removed successfully")
            self.removed_regular_waybar = True  # Track that we removed it
            return True
        else:
            self.log(f"Failed to remove regular waybar: {output}", "ERROR")
            return False
    
    def install_waybar_cava(self) -> bool:
        """Install waybar-cava package using paru"""
        self.log("Installing waybar-cava package...")
        
        success, output = self.run_command("paru -S --noconfirm waybar-cava", capture_output=True)
        if success:
            self.log("waybar-cava installed successfully")
            return True
        else:
            self.log(f"Failed to install waybar-cava: {output}", "ERROR")
            return False
    
    def check_dependencies(self) -> bool:
        """Check if required packages are installed"""
        self.log("Checking dependencies...")
        
        # Check if waybar-cava is installed first
        success, _ = self.run_command("pacman -Q waybar-cava")
        if not success:
            self.log("waybar-cava is not installed. Attempting to install...")
            # Remove regular waybar first if it exists
            if not self.remove_regular_waybar():
                return False
            # Install waybar-cava
            if not self.install_waybar_cava():
                self.log("Failed to install waybar-cava. Please run manually: paru -S waybar-cava", "ERROR")
                return False
        else:
            self.log("waybar-cava is already installed")
        
        # Check if cava is installed (fallback or standalone)
        success, _ = self.run_command("which cava")
        if not success:
            self.log("CAVA is not installed. Attempting to install...")
            if not self.install_cava():
                self.log("Failed to install CAVA. Please run manually: sudo pacman -S cava", "ERROR")
                return False
        else:
            self.log("CAVA is already installed")
        
        # Check audio backend
        backends = []
        if self.run_command("which pipewire")[0]:
            backends.append("pipewire")
        if self.run_command("which pulseaudio")[0]:
            backends.append("pulse")
        
        if not backends:
            self.log("No supported audio backend found (PipeWire/PulseAudio)", "WARN")
        else:
            self.log(f"Found audio backends: {', '.join(backends)}")
        
        return True
    
    def create_cava_config(self) -> bool:
        """Create optimized CAVA configuration for waybar"""
        self.log("Creating CAVA configuration...")
        
        # Create cava config directory
        self.cava_dir.mkdir(parents=True, exist_ok=True)
        
        # Detect audio input method
        if self.run_command("which pipewire")[0]:
            input_method = "pipewire"
        elif self.run_command("which pulseaudio")[0]:
            input_method = "pulse"
        else:
            input_method = "alsa"
        
        cava_config = f"""[general]
bars = 16
sensitivity = 100
bar_width = 2
bar_spacing = 1
framerate = 60

[input]
method = {input_method}

[output]
method = raw
raw_target = /dev/stdout
bit_format = 8bit
ascii_max_range = 7

[color]
gradient = 1
gradient_count = 6
gradient_color_1 = '#fab387'
gradient_color_2 = '#f9e2af' 
gradient_color_3 = '#a6e3a1'
gradient_color_4 = '#74c7ec'
gradient_color_5 = '#b4befe'
gradient_color_6 = '#cba6f7'

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 0.77
"""
        
        config_path = self.cava_dir / "config"
        config_path.write_text(cava_config)
        self.created_files.append(config_path)
        self.log(f"Created CAVA config at {config_path}")
        return True
    
    def backup_waybar_config(self) -> bool:
        """Create backup of current waybar config"""
        self.log("Creating backup of waybar config...")
        
        config_path = self.waybar_dir / "config"
        backup_path = self.waybar_dir / f"config.backup-{subprocess.run(['date', '+%Y%m%d-%H%M%S'], capture_output=True, text=True).stdout.strip()}"
        
        if config_path.exists():
            shutil.copy2(config_path, backup_path)
            self.backup_path = backup_path  # Store backup path for restoration
            self.log(f"Backup created: {backup_path}")
        
        return True
    
    def update_waybar_config(self) -> bool:
        """Add native CAVA module to waybar configuration"""
        self.log("Updating waybar configuration...")
        
        config_path = self.waybar_dir / "config"
        
        try:
            # Read current config
            with open(config_path, 'r') as f:
                config_text = f.read()
            
            # Parse JSON (handle comments and trailing commas)
            import re
            # Remove // comments and trailing whitespace
            config_text_clean = re.sub(r'\s*//.*', '', config_text)
            # Remove trailing commas before } and ]
            config_text_clean = re.sub(r',\s*}', '}', config_text_clean)
            config_text_clean = re.sub(r',\s*]', ']', config_text_clean)
            config = json.loads(config_text_clean)
            
            # Add cava to modules-right (after pulseaudio)
            modules_right = config.get("modules-right", [])
            if "pulseaudio" in modules_right:
                pulse_index = modules_right.index("pulseaudio")
                modules_right.insert(pulse_index + 1, "cava")
            else:
                modules_right.append("cava")
            
            config["modules-right"] = modules_right
            
            # Add native cava module configuration
            config["cava"] = {
                "framerate": 60,
                "autosens": 1,
                "sensitivity": 100,
                "bars": 16,
                "method": "pipewire",
                "input_delay": 1,
                "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
                "tooltip": False
            }
            
            # Write updated config
            with open(config_path, 'w') as f:
                json.dump(config, f, indent=4)
            
            self.log("Updated waybar configuration")
            return True
            
        except Exception as e:
            self.log(f"Failed to update waybar config: {e}", "ERROR")
            return False
    
    def update_waybar_css(self) -> bool:
        """Add CAVA styling to waybar CSS"""
        self.log("Adding CAVA styling to waybar CSS...")
        
        css_path = self.waybar_dir / "style.css"
        
        cava_css = """
/* CAVA Audio Visualizer */
#cava {
  color: @white;
  font-family: "Caskaydia Cove Nerd Font", monospace;
  font-size: 16px;
  padding: 0 12px;
  margin: 0 4px;
  background: @color0;
  border-radius: 6px;
  min-width: 150px;
}

#cava:hover {
  background: @color6;
  color: @color0;
}
"""
        
        try:
            with open(css_path, 'a') as f:
                f.write(cava_css)
            self.log("Added CAVA styling to CSS")
            return True
        except Exception as e:
            self.log(f"Failed to update CSS: {e}", "ERROR")
            return False
    
    def restart_waybar(self) -> bool:
        """Restart waybar to apply changes"""
        self.log("Restarting waybar...")
        
        # Kill existing waybar
        self.run_command("pkill waybar", capture_output=False)
        
        # Wait a moment
        subprocess.run(["sleep", "2"])
        
        # Start waybar
        success, _ = self.run_command("waybar &", capture_output=False)
        
        if success:
            self.log("Waybar restarted successfully")
        else:
            self.log("Failed to restart waybar", "ERROR")
        
        return success
    
    def restore_waybar_config(self):
        """Restore original waybar config from backup"""
        if not self.backup_path or not self.backup_path.exists():
            self.log("No backup found to restore", "WARN")
            return
        
        config_path = self.waybar_dir / "config"
        
        try:
            # Restore the backup to original config
            shutil.copy2(self.backup_path, config_path)
            self.log(f"Restored waybar config from {self.backup_path}")
            
            # Remove the backup file
            self.backup_path.unlink()
            self.log("Removed backup file")
        except Exception as e:
            self.log(f"Failed to restore waybar config: {e}", "ERROR")
    
    def restore_packages_on_failure(self):
        """Restore original package state if setup fails"""
        if not self.removed_regular_waybar:
            self.log("No package changes to revert")
            return
        
        self.log("Restoring original package state...", "WARN")
        
        # Remove waybar-cava if we installed it
        success, _ = self.run_command("pacman -Q waybar-cava")
        if success:
            self.log("Removing waybar-cava...")
            remove_success, output = self.run_command("sudo pacman -R --noconfirm waybar-cava", capture_output=True)
            if remove_success:
                self.log("waybar-cava removed successfully")
            else:
                self.log(f"Failed to remove waybar-cava: {output}", "ERROR")
        
        # Reinstall regular waybar
        self.log("Reinstalling regular waybar...")
        install_success, output = self.run_command("sudo pacman -S --noconfirm waybar", capture_output=True)
        if install_success:
            self.log("Regular waybar reinstalled successfully")
        else:
            self.log(f"Failed to reinstall regular waybar: {output}", "ERROR")
    
    def cleanup_on_failure(self):
        """Clean up files created during setup if something fails"""
        self.log("Cleaning up files created during setup...", "WARN")
        
        # First, restore package state
        self.restore_packages_on_failure()
        
        # Then, restore the original waybar config
        self.restore_waybar_config()
        
        # Then clean up created files
        for file_path in self.created_files:
            try:
                if file_path.exists():
                    file_path.unlink()
                    self.log(f"Removed: {file_path}")
            except Exception as e:
                self.log(f"Failed to remove {file_path}: {e}", "ERROR")
        
        # Also remove cava directory if we created it and it's empty
        try:
            if self.cava_dir.exists() and not any(self.cava_dir.iterdir()):
                self.cava_dir.rmdir()
                self.log(f"Removed empty directory: {self.cava_dir}")
        except Exception as e:
            self.log(f"Failed to remove directory {self.cava_dir}: {e}", "ERROR")
    
    def run_setup(self) -> bool:
        """Run the complete setup process"""
        self.log("Starting waybar-cava setup...")
        
        steps = [
            ("Checking dependencies", self.check_dependencies),
            ("Creating CAVA config", self.create_cava_config),
            ("Backing up waybar config", self.backup_waybar_config),
            ("Updating waybar config", self.update_waybar_config),
            ("Updating waybar CSS", self.update_waybar_css),
            ("Restarting waybar", self.restart_waybar)
        ]
        
        for step_name, step_func in steps:
            self.log(f"Step: {step_name}")
            if not step_func():
                self.log(f"Setup failed at step: {step_name}", "ERROR")
                self.cleanup_on_failure()
                return False
        
        self.log("Waybar-CAVA setup completed successfully!", "INFO")
        self.log("The native audio visualizer should now appear in your waybar.")
        return True

def main():
    """Main entry point"""
    if len(sys.argv) > 1 and sys.argv[1] in ["-h", "--help"]:
        print("Waybar-CAVA Setup Script")
        print("Usage: python3 setup_cava.py")
        print("\nThis script will:")
        print("1. Install waybar-cava package (native CAVA support)")
        print("2. Create optimized CAVA configuration")
        print("3. Update waybar configuration with native CAVA module")
        print("4. Add CAVA styling to CSS")
        print("5. Restart waybar")
        print("\nPrerequisites: paru for AUR package installation")
        return
    
    setup = WaybarCavaSetup()
    success = setup.run_setup()
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()