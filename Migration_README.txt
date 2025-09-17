================================================================================
                        NOESIS ARCH - FILE MIGRATION GUIDE
================================================================================

This guide shows where each file in this repository should be placed on your
system and explains their purpose.

================================================================================
HYPRLAND CONFIGURATION
================================================================================

config/hypr/hyprland.conf
  → ~/.config/hypr/hyprland.conf
  Purpose: Main Hyprland window manager configuration. Defines keybindings,
           window rules, animations, and launches fuzzel as the app launcher.

config/hypr/hyprlock.conf
  → ~/.config/hypr/hyprlock.conf
  Purpose: Lock screen configuration for Hyprland.

config/hypr/hyprpaper.conf
  → ~/.config/hypr/hyprpaper.conf
  Purpose: Wallpaper configuration for Hyprland.

================================================================================
WAYBAR CONFIGURATION
================================================================================

config/waybar/config
  → ~/.config/waybar/config
  Purpose: Waybar panel configuration. Defines modules, layout, and button
           actions including power menu, app launcher, btop, and network menu.

config/waybar/style.css
  → ~/.config/waybar/style.css
  Purpose: Waybar styling with dynamic pywal colors (updated by scripts).

config/waybar/powermenu-fuzzel.sh
  → ~/.config/waybar/powermenu-fuzzel.sh
  Purpose: Power menu script (shutdown/reboot/logout/lock/suspend) using fuzzel.
           Simplified to use fuzzel.ini for styling.

config/waybar/wifimenu-complete-refactored.sh
  → ~/.config/waybar/wifimenu-complete-refactored.sh
  Purpose: WiFi network manager menu using fuzzel and iwctl. Shows available
           networks, handles connections, and manages passwords.

================================================================================
FUZZEL CONFIGURATION
================================================================================

config/fuzzel/fuzzel.ini
  → ~/.config/fuzzel/fuzzel.ini
  Purpose: Global fuzzel launcher configuration with dynamic pywal colors.
           Defines colors, fonts, borders, and keybindings for all fuzzel menus.

================================================================================
MAKO CONFIGURATION
================================================================================

config/mako/config
  → ~/.config/mako/config
  Purpose: Notification daemon configuration with dynamic pywal colors.
           Defines notification appearance, positioning, timeouts, and urgency levels.

================================================================================
PACKAGE LISTS
================================================================================

packages/min-pacman-list.txt
  Purpose: Minimal essential pacman packages (49 packages vs 1046 full system).
           Includes: system base, Hyprland desktop, essential tools, drivers.
           Use: pacman -S --needed - < min-pacman-list.txt

packages/min-aur-list.txt
  Purpose: Minimal essential AUR packages (2 packages: pywal16, waybar-cava).
           Use: paru -S --needed - < min-aur-list.txt

packages/min-pkglist-ref.txt
  Purpose: Reference documentation showing all package categories and purposes.
           Complete breakdown of what each package provides.

================================================================================
BOOTSTRAP SCRIPT INSTALLATION
================================================================================

The automated bootstrap script (scripts/bootstrap.sh) handles complete system setup:

1. **Make Scripts Executable**: Sets permissions on all scripts
2. **Install Minimal Packages**: 49 essential packages with optimized mirrors
3. **Install AUR Packages**: 2 AUR packages (pywal16, waybar-cava)
4. **Create Directories**: All necessary config directories
5. **Migrate Configs**: Copies all configuration files
6. **Install Pywal Scripts**: Dynamic theming integration to ~/.local/bin/
7. **Copy System Files**: NVIDIA/ACPI system configurations
8. **Start Services**: Bluetooth, iwd, ly, ssh, reflector, pipewire
9. **Reload Configs**: Refreshes Hyprland configuration

Usage: cd ~/build/noesis-arch && ./scripts/bootstrap.sh

================================================================================
MANUAL INSTALLATION NOTES
================================================================================

1. **Package Installation**:
   # Minimal setup (recommended)
   sudo pacman -S --needed - < packages/min-pacman-list.txt
   paru -S --needed - < packages/min-aur-list.txt

2. **Pywal Integration**:
   - Copy scripts/pywal-integration/* to ~/.local/bin/
   - Ensure ~/.local/bin is in PATH
   - Scripts: fuzzel-pywal-update, hyprland-pywal-update, mako-pywal-update

3. **Service Requirements**:
   - fuzzel (application launcher and menus)
   - iwd (WiFi management, no NetworkManager)
   - ly (display manager)
   - pipewire (audio system)

4. **Make scripts executable**:
   chmod +x ~/.config/waybar/*.sh
   chmod +x ~/.local/bin/*-pywal-update

5. **Restart services**:
   - Reload Hyprland: hyprctl reload
   - Restart Waybar: pkill waybar && waybar &

================================================================================
KEY CHANGES IN THIS CONFIGURATION
================================================================================

• **Minimal Package System**: Reduced from 1046 to 49 packages (95% reduction)
• **Dynamic Theming**: Pywal integration with fuzzel, mako, waybar, hyprland
• **Optimized Bootstrap**: Automated setup with reflector mirror optimization
• **iwd Only**: No NetworkManager bloat, pure iwd wireless management
• **Fuzzel Everywhere**: Unified launcher system replacing wofi
• **Essential Focus**: Core functionality without gaming/AI/development bloat
================================================================================