# System-Agnostic Architecture Plan

## T15g-Specific Elements Found:

1. **Hardware-locked CLAUDE-PROTOCOL.md** - Contains exact T15g specs
2. **NVIDIA-only configurations** - `nvidia.conf` modprobe settings
3. **ThinkPad-specific settings** - `thinkpad_acpi.conf` for fan control
4. **Intel-only assumptions** - CPU microcode, thermal management
5. **Hard-coded reflector country** - US mirrors only
6. **Laptop-specific power management** - Mobile platform assumptions

## Proposed System-Agnostic Approach:

1. **Hardware Detection System**: Auto-detect CPU (Intel/AMD), GPU (NVIDIA/AMD/Intel), and form factor (laptop/desktop)
2. **Conditional Configuration**: Apply hardware-specific configs only when detected
3. **Modular Package Lists**: Separate base, Intel/AMD, NVIDIA/AMD, laptop/desktop packages
4. **Dynamic Protocol Generation**: Create CLAUDE-PROTOCOL.md based on detected hardware

## Implementation Strategy:

1. Create a hardware detection script
2. Make the bootstrap script hardware-aware
3. Split package lists by hardware type
4. Generate dynamic documentation

## Hardware Detection Requirements:

- CPU vendor detection (Intel vs AMD)
- GPU detection (NVIDIA, AMD, Intel integrated)
- Form factor detection (laptop vs desktop)
- Country/locale detection for mirror optimization
- ThinkPad-specific feature detection

## Modular Configuration Structure:

```
configs/
├── base/           # Universal configurations
├── cpu/
│   ├── intel/      # Intel-specific configs
│   └── amd/        # AMD-specific configs
├── gpu/
│   ├── nvidia/     # NVIDIA-specific configs
│   ├── amd/        # AMD GPU configs
│   └── intel/      # Intel integrated configs
├── platform/
│   ├── laptop/     # Laptop-specific configs
│   └── desktop/    # Desktop-specific configs
└── vendor/
    ├── thinkpad/   # ThinkPad-specific configs
    ├── dell/       # Dell-specific configs
    └── generic/    # Generic vendor configs
```

## Package List Structure:

```
packages/
├── base-pacman.txt        # Essential packages for all systems
├── intel-pacman.txt       # Intel CPU packages
├── amd-pacman.txt         # AMD CPU packages
├── nvidia-pacman.txt      # NVIDIA GPU packages
├── amd-gpu-pacman.txt     # AMD GPU packages
├── laptop-pacman.txt      # Laptop-specific packages
└── base-aur.txt          # Essential AUR packages
```

## Dynamic Documentation:

- Generate CLAUDE-PROTOCOL.md based on detected hardware
- Include only relevant hardware constraints
- Provide system-specific optimization recommendations
- Reference appropriate Arch Wiki articles for detected hardware