# Agnosis-Arch Project Status

## Project Overview
**Goal**: Transform T15g-specific "noesis-arch" into hardware-agnostic "agnosis-arch" that adapts to any system configuration.

**Original Problem**: Bootstrap script hardcoded NVIDIA drivers on all systems, causing installation failures on non-NVIDIA hardware.

## What We've Accomplished ✅

### 1. Hardware Detection System
- **File**: `scripts/detect-hardware.sh`
- **Capabilities**:
  - CPU vendor detection (Intel/AMD)
  - GPU detection (NVIDIA/AMD/Intel, including hybrid)
  - Platform detection (laptop/desktop)
  - Vendor detection (ThinkPad/Dell/HP/etc)
  - Country detection for mirror optimization
  - Feature detection (ThinkPad fan control, Optimus, etc)
- **Output formats**: JSON, environment variables, human-readable

### 2. Modular Package System
**Location**: `packages/` directory

**Structure**:
- `base-pacman.txt` (47 packages) - Universal packages
- `linux-zen-pacman.txt` / `linux-stable-pacman.txt` - Kernel choice
- `intel-cpu-pacman.txt` / `amd-cpu-pacman.txt` - CPU microcode
- `nvidia-gpu-pacman.txt` / `amd-gpu-pacman.txt` / `intel-gpu-pacman.txt` - GPU drivers
- `laptop-pacman.txt` - Power management (tlp, acpi)
- `thinkpad-pacman.txt` - Vendor-specific (acpi_call)
- `base-aur.txt` - Universal AUR packages

**Optimizations**:
- Eliminated redundancies (mesa/vulkan moved to base)
- Hardware-specific drivers only installed when detected
- Added broot to base packages

### 3. Hardware-Agnostic Bootstrap Script
- **File**: `scripts/bootstrap.sh`
- **Features**:
  - Runs hardware detection first
  - Dynamically selects package lists based on detected hardware
  - Country-specific mirror optimization
  - User choice for kernel (zen vs stable)
  - Proper error handling for unknown hardware

### 4. Updated Documentation
- **File**: `CLAUDE-PROTOCOL.md` - Now hardware-agnostic
- **File**: `SYSTEM-AGNOSTIC-PLAN.md` - Implementation strategy
- **File**: `PROJECT-STATUS.md` - This summary

### 5. GitHub Repository
- **URL**: https://github.com/lvnafir/agnosis-arch
- **Branch**: main
- **Status**: Live and ready for testing

## What Still Needs Work ❌

### 1. ✅ Modular System Configurations (COMPLETED)
- **Issue**: `system/modprobe.d/nvidia.conf` and `thinkpad_acpi.conf` were always copied
- **Solution**: Made hardware-conditional in bootstrap script
- **Result**: NVIDIA configs only copied on NVIDIA systems, ThinkPad configs only on ThinkPads

### 2. Migration Documentation
- **Issue**: `Migration_README.txt` still references old T15g-specific structure
- **Solution**: Update for new modular approach

### 3. System Testing
- **Issue**: Can't test on current T15g system (already has Arch installed)
- **Solution**: Test on T420s with fresh Arch installation

## T420s Test Plan

### Expected Hardware Detection:
- **CPU**: Intel → install intel-ucode
- **GPU**: Intel integrated → install mesa/vulkan-intel (NO NVIDIA drivers!)
- **Platform**: Laptop → install tlp/acpi
- **Vendor**: ThinkPad → install acpi_call
- **Total packages**: ~59 packages (base + intel-cpu + intel-gpu + laptop + thinkpad)

### Test Commands:
```bash
# After minimal Arch installation on T420s:
git clone https://github.com/lvnafir/agnosis-arch.git
cd agnosis-arch

# Test hardware detection
./scripts/detect-hardware.sh --validate

# Run bootstrap script
./scripts/bootstrap.sh
```

### Success Criteria:
1. ✅ No NVIDIA drivers installed (solving original issue)
2. ✅ Correct Intel CPU/GPU packages installed
3. ✅ Laptop power management configured
4. ✅ ThinkPad-specific features enabled
5. ✅ Hyprland desktop launches properly

## Technical Details for Reference

### Current Hardware Detection Output (T15g):
```json
{
    "cpu_vendor": "intel",
    "gpu_type": "nvidia",
    "platform": "laptop",
    "vendor": "generic",
    "country": "US",
    "features": "thinkpad_fan_control,thunderbolt,fingerprint"
}
```

### Expected T420s Detection:
```json
{
    "cpu_vendor": "intel",
    "gpu_type": "intel",
    "platform": "laptop",
    "vendor": "thinkpad",
    "country": "US",
    "features": "thinkpad_fan_control"
}
```

### Key Files Modified:
- `scripts/bootstrap.sh` - Hardware-agnostic installation logic
- `scripts/detect-hardware.sh` - NEW hardware detection system
- `packages/*.txt` - NEW modular package system
- `CLAUDE-PROTOCOL.md` - Updated documentation

### Files That Still Need Work:
- `system/modprobe.d/` - Make hardware-conditional
- `Migration_README.txt` - Update for new structure
- Bootstrap script system config section - Add hardware detection

## Next Session Tasks:
1. **Test T420s installation** - Validate hardware detection works
2. **Fix system configs** - Make modprobe.d files conditional
3. **Update documentation** - Migration guide and remaining references
4. **Merge to main** - After successful T420s test

## Repository Structure:
```
agnosis-arch/
├── scripts/
│   ├── bootstrap.sh (hardware-agnostic)
│   └── detect-hardware.sh (NEW)
├── packages/ (NEW modular structure)
│   ├── base-pacman.txt
│   ├── linux-{zen,stable}-pacman.txt
│   ├── {intel,amd}-cpu-pacman.txt
│   ├── {nvidia,amd,intel}-gpu-pacman.txt
│   ├── laptop-pacman.txt
│   ├── thinkpad-pacman.txt
│   └── base-aur.txt
├── config/ (unchanged)
├── system/ (needs hardware-conditional work)
└── docs/
    ├── CLAUDE-PROTOCOL.md (updated)
    ├── SYSTEM-AGNOSTIC-PLAN.md (NEW)
    └── PROJECT-STATUS.md (this file)
```

## Command Reference for T420s Setup:

### Manual Arch Installation Steps:
1. Boot USB, connect WiFi with `iwctl`
2. Partition disk with `cfdisk` (EFI + root)
3. Format: `mkfs.fat -F32 /dev/sda1` + `mkfs.ext4 /dev/sda2`
4. Mount and install: `pacstrap /mnt base linux linux-firmware`
5. Configure: timezone, locale, hostname, bootloader
6. Install essentials: `sudo git base-devel`
7. Create user with wheel group access

### Test agnosis-arch:
```bash
git clone https://github.com/lvnafir/agnosis-arch.git
cd agnosis-arch
./scripts/detect-hardware.sh
./scripts/bootstrap.sh
```

**Key Success Metric**: No NVIDIA packages installed on T420s!