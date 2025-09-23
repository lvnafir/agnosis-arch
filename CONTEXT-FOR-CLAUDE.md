# Context File for Claude Instance - agnosis-arch Bootstrap Issues

## Current Situation
The agnosis-arch bootstrap script has been successfully executed on a T420s system, but waybar is not launching automatically on Hyprland startup. The bootstrap script completed without errors, Hyprland is installed and working, but waybar requires manual launch.

## Project Overview
- **Repository**: https://github.com/lvnafir/agnosis-arch
- **Goal**: Hardware-agnostic Arch Linux configuration system
- **Original Issue**: T15g-specific "noesis-arch" hardcoded NVIDIA drivers, causing failures on non-NVIDIA systems
- **Solution**: Created modular package system with hardware detection

## Recent Work Completed
1. **Hardware Detection System** (`scripts/detect-hardware.sh`)
   - Detects CPU vendor, GPU type, platform, vendor
   - Fixed Intel GPU detection regex bug
   - Fixed AMD detection with word boundaries
   - Outputs JSON, env vars, or human-readable format

2. **Bootstrap Script Fixes** (`scripts/bootstrap.sh`)
   - Added hardware detection persistence: `echo "$hw_info" > /tmp/hardware-detection.env`
   - Fixed package database sync with `pacman -Sy`
   - Added terminal compatibility for kitty
   - Hardware-conditional system config copying
   - Dependencies: dmidecode, usbutils, pciutils, reflector

3. **Modular Package System** (`packages/` directory)
   - `base-pacman.txt` - Universal packages (47 packages)
   - Hardware-specific: `{intel,amd}-cpu-pacman.txt`, `{nvidia,amd,intel}-gpu-pacman.txt`
   - Platform-specific: `laptop-pacman.txt`, `thinkpad-pacman.txt`

## Current Test System (T420s)
- **Hardware**: Intel CPU, Intel GPU, Laptop, ThinkPad
- **Expected Detection**:
  ```json
  {
    "cpu_vendor": "intel",
    "gpu_type": "intel",
    "platform": "laptop",
    "vendor": "thinkpad"
  }
  ```
- **Expected Packages**: base + intel-cpu + intel-gpu + laptop + thinkpad (~59 packages)

## Current Issue: Desktop Components Not Auto-Starting
- Bootstrap script completed successfully
- Hyprland is installed and launches
- Waybar is installed but doesn't start automatically
- Waybar can be launched manually
- swww (wallpaper daemon) doesn't launch either
- swww can presumably be launched manually as well

## Key Files to Examine
1. **Hyprland Configuration**: Look for `hyprland.conf` or similar in:
   - `~/.config/hypr/`
   - `/etc/hypr/`
   - Check if copied from `config/hypr/` in repo

2. **Waybar Configuration**:
   - Should be in `~/.config/waybar/`
   - Check if properly copied from `config/waybar/` in repo

3. **Bootstrap Script**: `scripts/bootstrap.sh`
   - Check `copy_configurations()` function
   - Verify config copying logic

4. **Config Directory Structure**: `config/` in repo
   - Should contain all dotfile configurations
   - Check for proper Hyprland autostart configuration

## Previous Configuration Work
- **Waybar**: Previously configured cava visualization (32 bars, pipewire method)
- **Expected Configs**: Should include Hyprland, waybar, kitty, etc.

## Things to Check
1. **Hyprland Autostart**: Does hyprland.conf have `exec-once = waybar` and `exec-once = swww` or similar?
2. **Config Copying**: Were configs properly copied during bootstrap?
3. **File Permissions**: Are copied configs readable/executable?
4. **Dependencies**: Are all waybar and swww dependencies installed?
5. **Service Files**: Any systemd user services needed?
6. **swww Configuration**: Proper wallpaper daemon setup and initialization

## Repository Structure
```
agnosis-arch/
├── scripts/
│   ├── bootstrap.sh (hardware-agnostic)
│   └── detect-hardware.sh
├── packages/ (modular package lists)
├── config/ (dotfile configurations)
├── system/ (system-level configs, hardware-conditional)
└── docs/
```

## Expected Fixes Needed
- Hyprland configuration missing waybar autostart
- Bootstrap script not properly copying/enabling configurations
- Missing dependencies or service files
- File permission issues

## Instructions for Analysis
1. Examine the current system state on T420s
2. Check Hyprland configuration for autostart directives
3. Verify waybar configuration is properly installed
4. Identify what the bootstrap script missed or misconfigured
5. Provide specific fixes to implement in the repository
6. Create list of mistakes, blindspots, and missed considerations

## Testing Environment
- Fresh Arch installation on T420s
- Manual Arch base system completed
- agnosis-arch bootstrap script executed successfully
- User can provide SSH access if needed (password: 3psilon)

## Success Criteria
After fixes, both waybar and swww should automatically launch when Hyprland starts, providing the full desktop environment with working status bar and wallpaper daemon as intended.