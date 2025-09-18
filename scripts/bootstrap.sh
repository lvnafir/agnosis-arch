#!/bin/bash

set -e

REPO_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
CONFIG_DIR="$HOME/.config"

# Check if we're in a TTY (no color support)
if [ -t 1 ] && command -v tput &> /dev/null && tput colors &> /dev/null && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    # No color in TTY
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

print_header() {
    echo ""
    echo "================================================================================="
    echo "$1"
    echo "================================================================================="
}

print_success() {
    echo "[OK] $1"
}

print_error() {
    echo "[ERROR] $1"
}

print_info() {
    echo "[INFO] $1"
}

ask_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        echo -n "$prompt (y/n): "
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]) return 1 ;;
            *) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

chmod_all_scripts() {
    print_header "Making all scripts executable"
    
    find "$REPO_DIR/scripts" -type f -name "*.sh" -o -type f ! -name "*.*" | while read -r script; do
        if [[ -f "$script" && ! -x "$script" ]]; then
            chmod +x "$script"
            print_success "Made executable: $(basename "$script")"
        fi
    done
    
    if [[ -f "$CONFIG_DIR/waybar/powermenu-fuzzel.sh" ]]; then
        chmod +x "$CONFIG_DIR/waybar/powermenu-fuzzel.sh"
        print_success "Made executable: waybar/powermenu-fuzzel.sh"
    fi
    
    if [[ -f "$CONFIG_DIR/waybar/wifimenu-complete-refactored.sh" ]]; then
        chmod +x "$CONFIG_DIR/waybar/wifimenu-complete-refactored.sh"
        print_success "Made executable: waybar/wifimenu-complete-refactored.sh"
    fi

    if [[ -f "$CONFIG_DIR/waybar/appmenu-fuzzel.sh" ]]; then
        chmod +x "$CONFIG_DIR/waybar/appmenu-fuzzel.sh"
        print_success "Made executable: waybar/appmenu-fuzzel.sh"
    fi

    if [[ -f "$CONFIG_DIR/hypr/touchpad-config-toggle.sh" ]]; then
        chmod +x "$CONFIG_DIR/hypr/touchpad-config-toggle.sh"
        print_success "Made executable: hypr/touchpad-config-toggle.sh"
    fi
}

install_packages() {
    print_header "Installing minimal essential packages"

    PKGLIST="$REPO_DIR/packages/min-pacman-list.txt"

    if [[ ! -f "$PKGLIST" ]]; then
        print_error "Minimal package list not found: $PKGLIST"
        return 1
    fi

    # Update mirrors before package installation for faster downloads
    print_info "Updating package mirrors with reflector..."
    sudo reflector --country US --age 12 --protocol https --sort rate --connection-timeout 2 --save /etc/pacman.d/mirrorlist
    print_success "Updated package mirrors"

    print_info "Installing $(wc -l < "$PKGLIST") essential packages..."
    sudo pacman -Sy --needed --noconfirm - < "$PKGLIST"
    print_success "Essential package installation completed"
}

install_aur_packages() {
    print_header "Installing minimal AUR packages"

    AUR_PKGLIST="$REPO_DIR/packages/min-aur-list.txt"

    if [[ ! -f "$AUR_PKGLIST" ]]; then
        print_error "Minimal AUR package list not found: $AUR_PKGLIST"
        return 1
    fi

    # Check if paru is available
    if ! command -v paru &> /dev/null; then
        print_error "paru not found. Installing paru first..."

        # Install base-devel if not present
        sudo pacman -S --needed --noconfirm base-devel git

        # Clone and build paru
        cd /tmp
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd "$REPO_DIR"
        print_success "Installed paru AUR helper"
    fi

    print_info "Installing $(wc -l < "$AUR_PKGLIST") AUR packages..."
    while read -r package; do
        if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
            print_info "Installing AUR package: $package"
            paru -S --needed --noconfirm "$package" || print_error "Failed to install: $package"
        fi
    done < "$AUR_PKGLIST"
    print_success "AUR package installation completed"
}

create_directories() {
    print_header "Creating necessary directories"
    
    local dirs=(
        "$CONFIG_DIR/hypr"
        "$CONFIG_DIR/waybar"
        "$CONFIG_DIR/fuzzel"
        "$CONFIG_DIR/mako"
        "$CONFIG_DIR/kitty"
        "$CONFIG_DIR/ranger"
        "$CONFIG_DIR/wal/templates"
        "$HOME/Pictures/Screenshots"
        "$HOME/Pictures/wallpapers"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_info "Directory exists: $dir"
        fi
    done
}

migrate_config_files() {
    print_header "Migrating configuration files"
    
    declare -A files=(
        ["$REPO_DIR/config/hypr/hyprland.conf"]="$CONFIG_DIR/hypr/hyprland.conf"
        ["$REPO_DIR/config/hypr/hyprlock.conf"]="$CONFIG_DIR/hypr/hyprlock.conf"
        ["$REPO_DIR/config/hypr/hyprpaper.conf"]="$CONFIG_DIR/hypr/hyprpaper.conf"
        ["$REPO_DIR/config/hypr/colors.conf"]="$CONFIG_DIR/hypr/colors.conf"
        ["$REPO_DIR/config/hypr/pywal-decorations.conf"]="$CONFIG_DIR/hypr/pywal-decorations.conf"
        ["$REPO_DIR/config/hypr/touchpad-config-toggle.sh"]="$CONFIG_DIR/hypr/touchpad-config-toggle.sh"
        ["$REPO_DIR/config/waybar/config"]="$CONFIG_DIR/waybar/config"
        ["$REPO_DIR/config/waybar/style.css"]="$CONFIG_DIR/waybar/style.css"
        ["$REPO_DIR/config/waybar/powermenu-fuzzel.sh"]="$CONFIG_DIR/waybar/powermenu-fuzzel.sh"
        ["$REPO_DIR/config/waybar/wifimenu-complete-refactored.sh"]="$CONFIG_DIR/waybar/wifimenu-complete-refactored.sh"
        ["$REPO_DIR/config/waybar/appmenu-fuzzel.sh"]="$CONFIG_DIR/waybar/appmenu-fuzzel.sh"
        ["$REPO_DIR/config/waybar/setup_cava.py"]="$CONFIG_DIR/waybar/setup_cava.py"
        ["$REPO_DIR/config/fuzzel/fuzzel.ini"]="$CONFIG_DIR/fuzzel/fuzzel.ini"
        ["$REPO_DIR/config/mako/config"]="$CONFIG_DIR/mako/config"
        ["$REPO_DIR/config/ranger/rc.conf"]="$CONFIG_DIR/ranger/rc.conf"
        ["$REPO_DIR/config/ranger/rifle.conf"]="$CONFIG_DIR/ranger/rifle.conf"
        ["$REPO_DIR/config/ranger/scope.sh"]="$CONFIG_DIR/ranger/scope.sh"
        ["$REPO_DIR/config/ranger/commands.py"]="$CONFIG_DIR/ranger/commands.py"
        ["$REPO_DIR/config/ranger/commands_full.py"]="$CONFIG_DIR/ranger/commands_full.py"
        ["$REPO_DIR/config/wal/templates/colors-waybar.css"]="$CONFIG_DIR/wal/templates/colors-waybar.css"
    )
    
    for src in "${!files[@]}"; do
        dest="${files[$src]}"
        if [[ -f "$src" ]]; then
            if [[ -f "$dest" ]]; then
                print_info "Backing up existing: $(basename "$dest")"
                cp "$dest" "$dest.bak.$(date +%Y%m%d_%H%M%S)"
            fi
            cp "$src" "$dest"
            print_success "Migrated: $(basename "$src") → $(dirname "$dest" | sed "s|$HOME|~|")"
        else
            print_error "Source file not found: $src"
        fi
    done
    
    # Copy wallpapers
    if [[ -d "$REPO_DIR/wallpapers" ]]; then
        print_info "Copying wallpapers..."
        for wallpaper in "$REPO_DIR/wallpapers"/*; do
            if [[ -f "$wallpaper" ]]; then
                cp "$wallpaper" "$HOME/Pictures/wallpapers/"
                print_success "Copied wallpaper: $(basename "$wallpaper")"
            fi
        done
    fi
}

install_pywal_scripts() {
    print_header "Installing pywal integration scripts"

    if [[ ! -d "$HOME/.local/bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        print_success "Created ~/.local/bin directory"
    fi

    if [[ -d "$REPO_DIR/scripts/pywal-integration" ]]; then
        print_info "Copying pywal integration scripts..."
        for script in "$REPO_DIR/scripts/pywal-integration"/*; do
            if [[ -f "$script" ]]; then
                script_name=$(basename "$script")
                if [[ -f "$HOME/.local/bin/$script_name" ]]; then
                    print_info "Backing up existing: ~/.local/bin/$script_name"
                    cp "$HOME/.local/bin/$script_name" "$HOME/.local/bin/$script_name.bak.$(date +%Y%m%d_%H%M%S)"
                fi
                cp "$script" "$HOME/.local/bin/"
                chmod +x "$HOME/.local/bin/$script_name"
                print_success "Installed: $script_name → ~/.local/bin/"
            fi
        done

        # Ensure ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            print_info "Adding ~/.local/bin to PATH in ~/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            print_success "Added ~/.local/bin to PATH"
        else
            print_info "~/.local/bin already in PATH"
        fi
    else
        print_info "No pywal integration scripts to install"
    fi
}

copy_system_files() {
    print_header "Copying system configuration files"
    
    # Copy modprobe.d files for NVIDIA and system configuration
    if [[ -d "$REPO_DIR/system/modprobe.d" ]]; then
        print_info "Copying modprobe.d configurations..."
        for file in "$REPO_DIR/system/modprobe.d"/*.conf; do
            if [[ -f "$file" ]]; then
                filename=$(basename "$file")
                if [[ -f "/etc/modprobe.d/$filename" ]]; then
                    print_info "Backing up existing: /etc/modprobe.d/$filename"
                    sudo cp "/etc/modprobe.d/$filename" "/etc/modprobe.d/$filename.bak.$(date +%Y%m%d_%H%M%S)"
                fi
                sudo cp "$file" "/etc/modprobe.d/"
                print_success "Copied: $filename → /etc/modprobe.d/"
            fi
        done
        print_info "Regenerating initramfs for kernel module changes..."
        sudo mkinitcpio -P
        print_success "Initramfs regenerated"
    else
        print_info "No modprobe.d files to copy"
    fi
}

enable_services() {
    print_header "Enabling services"

    # Bluetooth service (bluez package)
    if systemctl is-enabled --quiet bluetooth; then
        print_info "Bluetooth is already enabled"
    else
        sudo systemctl enable bluetooth
        print_success "Enabled bluetooth service"
    fi

    # IWD for wireless networking
    if systemctl is-enabled --quiet iwd; then
        print_info "iwd is already enabled"
    else
        sudo systemctl enable iwd
        print_success "Enabled iwd service"
    fi

    # Ly display manager
    if systemctl is-enabled --quiet ly; then
        print_info "ly display manager is already enabled"
    else
        sudo systemctl enable ly
        print_success "Enabled ly display manager"
    fi

    # SSH daemon (openssh package)
    if systemctl is-enabled --quiet sshd; then
        print_info "SSH daemon is already enabled"
    else
        sudo systemctl enable sshd
        print_success "Enabled SSH daemon"
    fi

    # Reflector timer for mirrorlist updates
    if systemctl is-enabled --quiet reflector.timer; then
        print_info "Reflector timer is already enabled"
    else
        sudo systemctl enable reflector.timer
        print_success "Enabled reflector timer for mirrorlist updates"
    fi

    # Zram generator for swap compression
    if systemctl is-enabled --quiet systemd-zram-setup@zram0.service; then
        print_info "Zram is already configured"
    else
        sudo systemctl daemon-reload
        sudo systemctl enable systemd-zram-setup@zram0.service
        print_success "Enabled zram compression"
    fi

    # Pipewire and Wireplumber for audio (user services)
    systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true
    print_success "Enabled Pipewire audio services"

    print_info "Services enabled. They will start on next boot or can be started manually with 'systemctl start <service>'"
}

reload_configs() {
    print_header "Reloading configurations"
    
    if pgrep -x "Hyprland" > /dev/null; then
        hyprctl reload
        print_success "Reloaded Hyprland configuration"
    else
        print_info "Hyprland is not running"
    fi
}

main() {
    clear
    print_header "NOESIS ARCH BOOTSTRAP SCRIPT"
    echo "Repository: $REPO_DIR"
    echo "Configuration: $CONFIG_DIR"
    echo ""
    echo "This script will help you set up your Arch system with:"
    echo "  1. Make all scripts executable"
    echo "  2. Install minimal essential packages (~44 vs 1046)"
    echo "  3. Install minimal AUR packages (~2 vs 19)"
    echo "  4. Create necessary directories"
    echo "  5. Migrate configuration files"
    echo "  6. Install pywal integration scripts"
    echo "  7. Copy system files (modprobe.d for NVIDIA/ACPI)"
    echo "  8. Enable system services"
    echo "  9. Reload configurations"
    echo ""
    echo "You will be prompted at each major step."
    echo ""
    
    if ! ask_yes_no "Do you want to continue?"; then
        print_info "Bootstrap cancelled"
        exit 0
    fi
    
    # Step 1: Make scripts executable
    echo ""
    if ask_yes_no "Make all scripts executable?"; then
        chmod_all_scripts
    else
        print_info "Skipped making scripts executable"
    fi
    
    # Step 2: Install minimal essential packages
    echo ""
    echo "Minimal essential packages (~44 packages vs 1046 full list):"
    echo "  - System base, networking (iwd), drivers (nvidia)"
    echo "  - Hyprland desktop environment"
    echo "  - Essential tools (neovim, ranger, btop, chromium)"
    echo ""
    if ask_yes_no "Install minimal essential packages?"; then
        install_packages
    else
        print_info "Skipped minimal package installation"
    fi

    # Step 3: Install minimal AUR packages
    echo ""
    echo "Minimal AUR packages (~2 packages vs 19 full list):"
    if [[ -f "$REPO_DIR/packages/min-aur-list.txt" ]]; then
        cat "$REPO_DIR/packages/min-aur-list.txt" | sed 's/^/  - /'
    fi
    echo ""
    if ask_yes_no "Install minimal AUR packages (requires paru)?"; then
        install_aur_packages
    else
        print_info "Skipped minimal AUR package installation"
    fi
    
    # Step 4: Create directories
    echo ""
    if ask_yes_no "Create necessary configuration directories?"; then
        create_directories
    else
        print_info "Skipped directory creation"
    fi
    
    # Step 5: Migrate config files
    echo ""
    if ask_yes_no "Migrate configuration files (will backup existing files)?"; then
        migrate_config_files
    else
        print_info "Skipped config file migration"
    fi

    # Step 6: Install pywal scripts
    echo ""
    echo "Pywal integration scripts:"
    echo "  - fuzzel-pywal-update (dynamic fuzzel theming)"
    echo "  - hyprland-pywal-update (dynamic hyprland theming)"
    echo "  - mako-pywal-update (dynamic notification theming)"
    echo "  - wallpaper (wallpaper management script)"
    echo ""
    if ask_yes_no "Install pywal integration scripts to ~/.local/bin/?"; then
        install_pywal_scripts
    else
        print_info "Skipped pywal script installation"
    fi
    
    # Step 7: Copy system files
    echo ""
    echo "System files to copy:"
    echo "  - nvidia.conf (NVIDIA driver settings for Wayland)"
    echo "  - blacklist-ucsi.conf (fix ACPI errors)"
    echo "  - thinkpad_acpi.conf (ThinkPad fan control)"
    echo ""
    if ask_yes_no "Copy system configuration files (requires sudo)?"; then
        copy_system_files
    else
        print_info "Skipped system file configuration"
    fi
    
    # Step 8: Enable services
    echo ""
    echo "Services to enable:"
    echo "  - bluetooth (Bluetooth support)"
    echo "  - iwd (wireless networking)"
    echo "  - ly (display manager)"
    echo "  - sshd (SSH server)"
    echo "  - reflector.timer (mirrorlist updates)"
    echo "  - zram (compressed swap)"
    echo "  - pipewire (audio)"
    echo ""
    if ask_yes_no "Enable system services?"; then
        enable_services
    else
        print_info "Skipped service configuration"
    fi
    
    # Step 9: Reload configurations
    echo ""
    if ask_yes_no "Reload Hyprland configuration (if running)?"; then
        reload_configs
    else
        print_info "Skipped configuration reload"
    fi
    
    print_header "Bootstrap Complete!"
    print_success "System has been configured according to the migration guide"
    print_info "You may need to log out and back in for all changes to take effect"
    echo ""
    echo "Next steps:"
    echo "  1. If in TTY, reboot or login via ly to start Hyprland"
    echo "  2. Check that all services are running: systemctl status"
    echo "  3. Test your Hyprland configuration"
    echo ""
}

main "$@"