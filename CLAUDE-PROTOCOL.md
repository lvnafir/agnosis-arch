# Claude Code Protocol for Agnosis Arch System

**System Profile**: Hardware-agnostic Arch Linux configuration with Hyprland
**Generated**: 2025-09-22
**Purpose**: Comprehensive guidance for Claude Code interactions on diverse hardware configurations

## Hardware Detection & Adaptation

### Dynamic Hardware Support
This configuration automatically detects and adapts to different hardware configurations:

**Supported CPU Architectures**:
- Intel x86_64 (with intel-ucode microcode updates)
- AMD x86_64 (with amd-ucode microcode updates)
- Automatic detection via `/proc/cpuinfo` vendor identification

**Supported GPU Configurations**:
- NVIDIA discrete graphics (with proprietary nvidia drivers)
- AMD discrete graphics (with mesa/amdgpu drivers)
- Intel integrated graphics (with mesa/i915 drivers)
- Hybrid configurations (automatic detection and setup)

**Platform Support**:
- Laptop configurations (with power management, thermal control)
- Desktop configurations (with performance optimizations)
- Automatic detection via DMI/ACPI information

**Vendor-Specific Features**:
- ThinkPad (fan control, TrackPoint, special keys)
- Dell (thermal management, function keys)
- Generic laptop features (brightness, battery management)

### Hardware Detection Commands
The bootstrap script uses these commands for hardware detection:

```bash
# CPU vendor detection
grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2 | tr -d ' '

# GPU detection
lspci | grep -E "(VGA|3D|Display)"

# Platform detection
dmidecode -s chassis-type 2>/dev/null || echo "unknown"

# Laptop vendor detection
dmidecode -s system-manufacturer 2>/dev/null || echo "unknown"
```

### Adaptive Configuration Strategy

**CPU-Specific Adaptations**:
- Intel: intel-ucode, Intel Turbo Boost, thermal management
- AMD: amd-ucode, AMD Cool'n'Quiet, AMDGPU integration

**GPU-Specific Adaptations**:
- NVIDIA: proprietary drivers, CUDA support, Wayland compatibility
- AMD: mesa drivers, Vulkan/OpenGL support, power management
- Intel: integrated graphics optimization, Wayland native support

**Platform-Specific Adaptations**:
- Laptop: TLP power management, thermal throttling, suspend/hibernate
- Desktop: performance governors, advanced cooling, multi-monitor

## Operating System & Environment

### Arch Linux Configuration
- **Distribution**: Arch Linux (rolling release)
- **Kernel**: linux-zen (optimized for desktop/laptop performance)
- **Init System**: systemd
- **Display Server**: Wayland (via Hyprland compositor)
- **Package Manager**: pacman (primary), paru (AUR helper)

### Desktop Environment Stack
- **Compositor**: Hyprland (latest stable)
- **Status Bar**: waybar (with hardware-adaptive modules)
- **Application Launcher**: fuzzel (lightweight and fast)
- **Notifications**: mako (Wayland-native)
- **Screen Locker**: hyprlock (Wayland-compatible)
- **Wallpaper Manager**: swww (efficient Wayland wallpaper daemon)
- **Theme**: Catppuccin Mocha (system-wide, pywal integration)

### Adaptive System Components
- **Audio**: PipeWire (universal audio server)
- **Network**: iwd (for WiFi) + systemd-networkd (for Ethernet)
- **Power Management**: TLP (laptops) or performance governors (desktops)
- **Thermal Control**: Hardware-specific (ThinkPad fan control, generic laptop thermal management)
- **Graphics Drivers**: Auto-detected and installed per hardware

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
- **CPU Optimizations**: Detect and apply vendor-specific optimizations (Intel Turbo Boost, AMD Cool'n'Quiet, appropriate microcode)
- **GPU Solutions**: Auto-configure drivers and tools based on detected hardware (nvidia-smi for NVIDIA, radeontop for AMD, intel-gpu-tools for Intel)
- **Power Management**: Adapt power profiles based on platform (laptop TLP configuration, desktop performance governors)
- **Module Loading**: Apply hardware-specific modules and configurations (ThinkPad fan control, vendor-specific quirks)

## Directory Structure & File Organization

### Agnosis Arch Repository Structure
Primary configuration location: `~/build/agnosis-arch/`

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
# CPU microcode (auto-selected based on vendor)
intel-ucode OR amd-ucode
# GPU drivers (auto-selected based on hardware)
nvidia-dkms nvidia-utils nvidia-settings OR mesa vulkan-radeon OR mesa vulkan-intel
```

**Hyprland Desktop Stack**:
```
hyprland waybar fuzzel mako hyprlock
swww xdg-desktop-portal-hyprland
xorg-xwayland pipewire pipewire-pulse wireplumber
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

### GPU Driver Issues
**Common Problems**:
- Driver not loading after updates
- Wayland compatibility issues
- Hardware acceleration failures

**NVIDIA-Specific Resolution**:
1. Verify module loading: `lsmod | grep nvidia`
2. Check for nouveau conflicts: `lsmod | grep nouveau`
3. Ensure proper kernel parameters: `nvidia-drm.modeset=1`
4. Rebuild initramfs after module changes: `mkinitcpio -P`

**AMD-Specific Resolution**:
1. Verify module loading: `lsmod | grep amdgpu`
2. Check firmware loading: `dmesg | grep amdgpu`
3. Ensure proper kernel parameters for older cards: `radeon.si_support=0 amdgpu.si_support=1`

### Wayland/Hyprland GPU Integration
**NVIDIA Environment Variables**:
```
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
```

**AMD Environment Variables**:
```
LIBVA_DRIVER_NAME=radeonsi
GBM_BACKEND=mesa
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
**CPU Optimizations (Hardware-Detected)**:
- Intel: Enable Turbo Boost, configure thermal management, install intel-ucode
- AMD: Enable Cool'n'Quiet, configure power profiles, install amd-ucode
- Universal: Set appropriate CPU governor, monitor thermal throttling

**GPU Optimizations (Hardware-Detected)**:
- NVIDIA: nvidia-smi monitoring, persistence daemon, power management
- AMD: radeontop monitoring, AMDGPU power profiles, Mesa optimizations
- Intel: intel-gpu-tools, integrated graphics power management

## Interaction Guidelines Summary

1. **Hardware Agnostic**: Provide Arch Linux solutions that adapt to detected hardware (Intel/AMD CPU, NVIDIA/AMD/Intel GPU)
2. **Research First**: Verify current syntax and tool availability before recommendations
3. **No Sudo Access**: Present commands for user execution with clear instructions
4. **Dynamic Hardware Awareness**: Auto-detect and leverage hardware-specific capabilities while accounting for platform constraints
5. **Rolling Release Considerations**: Always verify that solutions are current and supported
6. **Clean Operations**: Ensure build hygiene and provide cleanup steps
7. **Reproducible Solutions**: Design deterministic, repeatable procedures that work across hardware configurations
8. **Arch Way Compliance**: Follow simplicity, modernity, and user control principles

## Verification Commands

**System Health Checks**:
```bash
uname -a                              # Kernel version
lspci | grep -E "(VGA|3D|Display)"   # GPU hardware detection
lsmod | grep -E "(nvidia|amdgpu|i915)" # GPU driver modules
systemctl --user status mako waybar   # Desktop services
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

This protocol ensures Claude Code provides relevant, accurate, and hardware-appropriate assistance for diverse Arch Linux system configurations through dynamic hardware detection and adaptive configuration management.