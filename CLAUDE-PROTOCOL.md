# Claude Code Protocol for Noesis Arch System

**System Profile**: Lenovo ThinkPad T15g Gen 1 running Arch Linux with Hyprland
**Generated**: 2025-09-17
**Purpose**: Comprehensive guidance for Claude Code interactions on this specific system

## Hardware Profile & Constraints

### Verified System Specifications
Based on system audit data from 2025-09-16:

**CPU**: Intel(R) Core(TM) i7-10850H @ 2.70GHz
- Architecture: x86_64 Comet Lake (10th gen)
- Cores: 6 physical, 12 logical (hyperthreading)
- Base frequency: 2.70GHz, Max boost: 5.10GHz
- Cache: L1d/L1i 192 KiB (6 instances each), L2 1.5 MiB (6 instances), L3 12 MiB
- Features: VT-x, Intel SGX, AVX2, AES-NI

**GPU**: NVIDIA GeForce RTX 2070 Super with Max-Q Design
- Device ID: 10de:1e91 (TU104M)
- VRAM: 8192 MB dedicated
- Driver: nvidia 580.82.09
- Vulkan: 1.4.321 support
- OpenGL: 4.6.0 support

**Display**: BOE 0x0853
- Resolution: 1920x1080
- DPI: 142
- Size: 15.5" diagonal
- Interface: eDP-1

**Storage**: Samsung NVMe SSD Controller PM9C1a (DRAM-less)
- Interface: PCIe NVMe
- Device location: /dev/nvme0n1

**Network**:
- WiFi: Intel Comet Lake PCH CNVi WiFi
- Ethernet: Intel Ethernet Connection (11) I219-LM

**Other Notable Hardware**:
- Thunderbolt 3 controller (Intel JHL7540 Titan Ridge 4C)
- Realtek RTS525A PCIe Card Reader
- Bison Integrated Camera (USB)

### Hardware-Specific Constraints

**INTEL ONLY**: This system contains Intel CPU architecture exclusively. Do not suggest AMD-specific solutions, optimizations, or tools (e.g., amd-ucode, amd-gpu drivers, ryzen-specific optimizations).

**NVIDIA ONLY**: This system uses NVIDIA discrete graphics exclusively. Do not suggest AMD GPU solutions (e.g., mesa-amd, amdgpu drivers, RADV), Intel integrated graphics optimizations, or multi-GPU AMD/Intel hybrid solutions.

**MOBILE PLATFORM**: This is a laptop with power management considerations. Prioritize solutions that account for thermal throttling, power efficiency, and mobile-specific hardware constraints.

## Operating System & Environment

### Arch Linux Configuration
- **Distribution**: Arch Linux (rolling release)
- **Kernel**: linux-zen (custom builds via noesis-arch)
- **Init System**: systemd
- **Display Server**: Wayland (via Hyprland compositor)
- **Package Manager**: pacman (primary), yay/paru (AUR)

### Desktop Environment Stack
- **Compositor**: Hyprland 0.51.0
- **Status Bar**: waybar
- **Application Launcher**: fuzzel (replaced wofi)
- **Notifications**: mako
- **Screen Locker**: hyprlock
- **Wallpaper Manager**: hyprpaper
- **Theme**: Catppuccin Mocha (system-wide)

### Current System State
- **Kernel Version**: 6.16.6-zen1-1-zen (as of last audit)
- **Display Server**: Xwayland 24.1.8 running under Hyprland
- **GPU Driver State**: nvidia 580.82.09 loaded and functional
- **Vulkan Layers**: Steam overlay and fossilize layers present

## Command & Interaction Protocols

### Research-First Approach
Before proposing any solution:
1. **Verify Current Syntax**: Check man pages, use `--help` flags, or conduct web searches to ensure command syntax is current for rolling release Arch
2. **Validate Tool Availability**: Confirm tools exist in Arch repositories before recommending
3. **Check Hardware Compatibility**: Ensure solutions are compatible with Intel/NVIDIA hardware stack

### Sudo Command Handling
Claude Code does not have sudo privileges. When sudo commands are required:
1. **Present the command** to the user with clear explanation
2. **Request execution confirmation**: "Please run this command and let me know when complete"
3. **Ask for output when needed**: "Please paste the output if there are any errors"
4. **Provide verification steps**: Suggest commands to verify successful completion

### Arch Linux Specificity Protocol
- **Repository Priority**: Use official Arch repositories first, then AUR as needed
- **Avoid Cross-Distribution Solutions**: Do not suggest Ubuntu PPAs, Fedora DNF commands, or generic Linux solutions
- **Use Arch-Specific Tools**: Prefer `pacman`, `makepkg`, `systemctl`, and Arch-native utilities
- **Reference Arch Wiki**: When suggesting complex procedures, reference relevant Arch Wiki articles

### Hardware-Aware Solutions
- **CPU Optimizations**: Focus on Intel-specific features (Intel Turbo Boost, thermal management, intel-ucode)
- **GPU Solutions**: Prioritize NVIDIA-specific tools (nvidia-smi, nvidia-settings, CUDA/Vulkan for NVIDIA)
- **Power Management**: Consider laptop-specific power profiles and thermal constraints
- **Module Loading**: Account for laptop-specific modules and hardware quirks

## Directory Structure & File Organization

### Noesis Arch Repository Structure
Primary configuration location: `~/build/noesis-arch/`

**Core Configuration Directories**:
- `config/hypr/` - Hyprland window manager configuration
- `config/waybar/` - Status bar configuration and scripts
- `config/fuzzel/` - Application launcher configuration
- `config/mako/` - Notification daemon configuration

**Script Directories**:
- `scripts/bootstrap.sh` - Main system setup script
- `scripts/build/` - Kernel and package build scripts
- `scripts/system/` - System management and diagnostic tools

**Active Configuration Locations**:
- `~/.config/hypr/` - Active Hyprland config
- `~/.config/waybar/` - Active waybar config (includes custom scripts)
- `~/.config/fuzzel/` - Active fuzzel config
- `~/.config/mako/` - Active mako config

### Build and Development Locations
- `~/build/` - General build directory for AUR packages and custom software
- `~/Scripts/` - User-specific scripts
- `~/Documents/` - System context files and documentation

## Package Management & System Maintenance

### Core Package Categories

**Essential System Packages**:
```
base base-devel linux-zen linux-zen-headers
intel-ucode nvidia-dkms nvidia-utils nvidia-settings
```

**Hyprland Desktop Stack**:
```
hyprland waybar fuzzel mako hyprlock hyprpaper
xorg-xwayland pipewire wireplumber
```

**Network & Communication**:
```
networkmanager iwctl openssh
```

**Development Tools**:
```
git vim neovim python rust go
vulkan-tools mesa-utils
```

### System Service Management
**Essential Services**:
- `systemctl enable NetworkManager` - Network management
- `systemctl --user enable pipewire pipewire-pulse` - Audio
- `systemctl --user enable mako` - Notifications

**GPU Services**:
- `systemctl enable nvidia-persistenced` - NVIDIA persistence daemon
- Ensure user in `video` group for GPU access

### Kernel Module Management
**Critical Modules for Hardware**:
- `nvidia nvidia_modeset nvidia_uvm nvidia_drm` - NVIDIA graphics
- `sd_mod usb_storage` - USB storage support
- `intel_rapl` - Intel power management

**Module Loading Issues**:
- Kernel/module version mismatches cause hardware failures
- Always reboot after kernel updates to ensure module compatibility
- Use `modprobe` to test module loading before system changes

## Known Issues & Solutions

### USB Storage Detection Problems
**Symptoms**: Device appears in `lsusb` but not `lsblk`
**Root Cause**: Kernel version mismatch with installed modules
**Solution**: Reboot to use current kernel matching installed modules
**Prevention**: Always reboot after kernel/module package updates

### NVIDIA Driver Issues
**Common Problems**:
- Driver not loading after updates
- Wayland compatibility issues
- CUDA applications failing

**Standard Resolution**:
1. Verify module loading: `lsmod | grep nvidia`
2. Check for nouveau conflicts: `lsmod | grep nouveau`
3. Ensure proper kernel parameters: `nvidia-drm.modeset=1`
4. Rebuild initramfs after module changes: `mkinitcpio -P`

### Wayland/Hyprland GPU Integration
**Required Environment Variables**:
```
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
```

**Service Reload Commands**:
```bash
hyprctl reload                    # Reload Hyprland config
pkill waybar && waybar &         # Restart waybar
systemctl --user restart mako   # Restart notifications
```

## Development & Build Protocols

### Custom Kernel Builds
- Use noesis-arch build scripts in `scripts/build/`
- Ensure clean build environment before compilation
- Verify module compatibility after kernel installation
- Maintain `modprobed.db` for module optimization

### AUR Package Management
- Build in `~/build/` directory for organization
- Always review PKGBUILDs before building
- Handle build dependencies through official repos when possible
- Clean build directories after successful installation

### System Optimization
**Intel CPU Optimizations**:
- Enable Intel Turbo Boost
- Configure appropriate CPU governor
- Monitor thermal throttling under load

**NVIDIA GPU Optimizations**:
- Use nvidia-smi for monitoring and configuration
- Enable NVIDIA persistence daemon
- Configure appropriate power management modes

## Interaction Guidelines Summary

1. **System Specificity**: Only provide Arch Linux solutions for Intel/NVIDIA hardware
2. **Research First**: Verify current syntax and tool availability before recommendations
3. **No Sudo Access**: Present commands for user execution with clear instructions
4. **Hardware Awareness**: Leverage Intel/NVIDIA specific capabilities and account for laptop constraints
5. **Rolling Release Considerations**: Always verify that solutions are current and supported
6. **Clean Operations**: Ensure build hygiene and provide cleanup steps
7. **Reproducible Solutions**: Design deterministic, repeatable procedures
8. **Arch Way Compliance**: Follow simplicity, modernity, and user control principles

## Verification Commands

**System Health Checks**:
```bash
uname -a                    # Kernel version
nvidia-smi                  # GPU status
lsmod | grep nvidia        # NVIDIA modules
systemctl --user status mako waybar  # Desktop services
```

**Hardware Detection**:
```bash
lscpu                      # CPU information
lspci | grep VGA          # Graphics hardware
lsblk                     # Storage devices
lsusb                     # USB devices
```

**Service Status**:
```bash
systemctl status NetworkManager
systemctl --user list-units --failed
journalctl -p 3 -xb       # System errors since boot
```

This protocol ensures Claude Code provides relevant, accurate, and hardware-appropriate assistance for this specific Arch Linux system configuration.