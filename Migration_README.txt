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
  Purpose: Waybar styling with Catppuccin Mocha theme colors.

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
  Purpose: Global fuzzel launcher configuration with Catppuccin Mocha theme.
           Defines colors, fonts, borders, and keybindings for all fuzzel menus.

================================================================================
PACKAGE LISTS
================================================================================

packages/pacman-pkglist-exp.txt
  Purpose: List of explicitly installed pacman packages (manually installed).
           Use: pacman -S --needed - < pacman-pkglist-exp.txt

packages/pacman-pkglist-all.txt
  Purpose: Complete list of all installed pacman packages.
           Reference for full system package state.

packages/pacman-pkglist-deps.txt
  Purpose: List of dependency packages (automatically installed).
           Reference for packages pulled in as dependencies.

packages/aur-pkglist-all.txt
  Purpose: List of all AUR (Arch User Repository) packages.
           Use with paru or yay for installation.

================================================================================
INSTALLATION NOTES
================================================================================

1. Fuzzel has replaced wofi as the application launcher and menu system.
   - All menus use unified styling from fuzzel.ini
   - No need for wofi configuration anymore

2. The waybar scripts require:
   - fuzzel (for menus)
   - iwctl (for WiFi management)
   - notify-send (for notifications)
   - systemctl (for power operations)
   - hyprlock (for screen locking)

3. Make scripts executable after copying:
   chmod +x ~/.config/waybar/*.sh

4. Restart services after copying configs:
   - Reload Hyprland config: hyprctl reload
   - Restart Waybar: pkill waybar && waybar &

================================================================================
KEY CHANGES IN THIS CONFIGURATION
================================================================================

• Switched from wofi to fuzzel for all menus
• Unified theming through fuzzel.ini (Catppuccin Mocha)
• Simplified scripts - styling moved to central config
• Added btop button to waybar (replaced easyeffects)
• App menu button now launches fuzzel directly
• Vim-style keybindings in fuzzel (j/k for navigation)

================================================================================