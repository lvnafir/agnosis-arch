#!/bin/bash

set -e

# Fix terminal compatibility issues (kitty, etc.)
if [[ "$TERM" == "xterm-kitty" ]] && ! infocmp xterm-kitty &>/dev/null; then
    export TERM=xterm-256color
fi

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
    # No color support detected
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

print_warning() {
    echo "[WARNING] $1"
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

safe_parse_hw_info() {
    local hw_info="$1"
    local allowed_vars="GPU_TYPE CPU_TYPE CPU_VENDOR LAPTOP_BRAND SYSTEM_TYPE PLATFORM GPU_DRIVER COUNTRY FEATURES"

    # Validate input is not empty
    [[ -n "$hw_info" ]] || {
        print_error "Hardware info is empty"
        return 1
    }

    # Parse each line safely
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] || continue

        # Validate format: VAR="value" only
        if [[ "$line" =~ ^([A-Z_]+)=\"([^\"]+)\"$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"

            # Check if variable is in allowed list
            if [[ " $allowed_vars " =~ " $var_name " ]]; then
                # Sanitize value (remove dangerous characters)
                var_value="${var_value//[\$\`\\]/}"
                declare -g "$var_name=$var_value"
            else
                print_info "Skipping unknown variable: $var_name"
            fi
        else
            print_info "Skipping invalid line format: $line"
        fi
    done <<< "$hw_info"
}

safe_load_hw_file() {
    local hw_file="$1"
    local allowed_vars="GPU_TYPE CPU_TYPE CPU_VENDOR LAPTOP_BRAND SYSTEM_TYPE PLATFORM GPU_DRIVER COUNTRY FEATURES"

    # Validate file exists and is readable
    [[ -f "$hw_file" && -r "$hw_file" ]] || {
        print_error "Hardware file not found or not readable: $hw_file"
        return 1
    }

    # Check file size (prevent reading huge files)
    local file_size=$(stat -c%s "$hw_file" 2>/dev/null || echo 0)
    if [[ $file_size -gt 1024 ]]; then
        print_error "Hardware file too large (${file_size} bytes): $hw_file"
        return 1
    fi

    # Read and validate file content
    local content
    content=$(cat "$hw_file") || {
        print_error "Failed to read hardware file: $hw_file"
        return 1
    }

    # Validate content format (only safe variable assignments)
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] || continue

        # Check for dangerous patterns
        if [[ "$line" =~ [\$\`\(\)\|\&\;\<\>] ]]; then
            print_error "Hardware file contains unsafe characters: $hw_file"
            return 1
        fi

        # Validate format: VAR="value" only
        if ! [[ "$line" =~ ^[A-Z_]+=\"[^\"]*\"$ ]]; then
            print_error "Hardware file has invalid format: $hw_file"
            return 1
        fi
    done <<< "$content"

    # Parse variables safely
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] || continue

        if [[ "$line" =~ ^([A-Z_]+)=\"([^\"]+)\"$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"

            # Check if variable is in allowed list
            if [[ " $allowed_vars " =~ " $var_name " ]]; then
                # Additional sanitization
                var_value="${var_value//[\$\`\\]/}"
                declare -g "$var_name=$var_value"
                print_info "Loaded: $var_name=$var_value"
            else
                print_info "Skipping unknown variable: $var_name"
            fi
        fi
    done <<< "$content"

    return 0
}

chmod_all_scripts() {
    print_header "Making all scripts executable"

    # Validate required paths
    [[ -d "$REPO_DIR" ]] || {
        print_error "Repository directory not found: $REPO_DIR"
        return 1
    }

    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_info "Creating configuration directory: $CONFIG_DIR"
        if mkdir -p "$CONFIG_DIR"; then
            print_success "Created configuration directory"
        else
            print_error "Failed to create configuration directory: $CONFIG_DIR"
            return 1
        fi
    fi

    local made_executable=0 failed=0

    # Process repository scripts using arrays instead of subshells
    if [[ -d "$REPO_DIR/scripts" ]]; then
        print_info "Processing repository scripts..."

        local repo_scripts=()
        while IFS= read -r -d '' script; do
            repo_scripts+=("$script")
        done < <(find "$REPO_DIR/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -print0)

        for script in "${repo_scripts[@]}"; do
            if [[ -f "$script" && ! -x "$script" ]]; then
                if chmod +x "$script"; then
                    print_success "Made executable: $(basename "$script")"
                    made_executable=$((made_executable + 1))
                else
                    print_error "Failed to make executable: $(basename "$script")"
                    failed=$((failed + 1))
                fi
            fi
        done
    else
        print_info "No scripts directory found in repository"
    fi

    # Process config scripts dynamically
    print_info "Processing configuration scripts..."

    local config_scripts=()
    while IFS= read -r -d '' script; do
        [[ -f "$script" ]] && config_scripts+=("$script")
    done < <(find "$CONFIG_DIR" \( -name "*.sh" -o -name "*.py" \) -type f -print0 2>/dev/null)

    for script in "${config_scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            if chmod +x "$script"; then
                local rel_path="${script#$CONFIG_DIR/}"
                print_success "Made executable: $rel_path"
                made_executable=$((made_executable + 1))
            else
                print_error "Failed to make executable: $script"
                failed=$((failed + 1))
            fi
        fi
    done

    # Summary
    print_info "Script permissions: $made_executable made executable, $failed failed"

    if [[ $failed -gt 0 ]]; then
        print_error "Some scripts failed to become executable"
        return 1
    fi

    return 0
}

install_packages() {
    print_header "Hardware-aware package installation"

    # Sync package database first
    print_info "Syncing package database..."
    sudo pacman -Sy

    # Install hardware detection dependencies first
    print_info "Installing hardware detection dependencies..."
    sudo pacman -S --needed --noconfirm dmidecode usbutils pciutils reflector

    # Detect hardware
    print_info "Detecting hardware configuration..."
    if [[ ! -f "$REPO_DIR/scripts/detect-hardware.sh" ]]; then
        print_error "Hardware detection script not found"
        return 1
    fi

    # Source hardware detection
    local hw_info=$("$REPO_DIR/scripts/detect-hardware.sh" --env)
    if ! safe_parse_hw_info "$hw_info"; then
        print_error "Failed to parse hardware detection results"
        return 1
    fi

    # Save hardware detection results for later use
    echo "$hw_info" > /tmp/hardware-detection.env

    print_success "Hardware detected: $CPU_VENDOR CPU, $GPU_TYPE GPU, $PLATFORM platform"
    if [[ -n "$FEATURES" ]]; then
        print_info "Special features: $FEATURES"
    fi

    # Update mirrors with detected country
    if [[ -n "$COUNTRY" ]]; then
        print_info "Updating package mirrors for $COUNTRY..."
        if sudo reflector --country "$COUNTRY" --age 12 --protocol https --sort rate --connection-timeout 2 --save /etc/pacman.d/mirrorlist; then
            print_success "Updated package mirrors"
        else
            print_warning "Failed to update mirrors for $COUNTRY, using default mirrors"
        fi
    else
        print_info "No country detected, using default mirrors"
    fi

    # Collect package lists to install
    local package_lists=()
    local total_packages=0

    # Base packages (always installed)
    package_lists+=("$REPO_DIR/packages/base-pacman.txt")

    # Kernel choice (ask user or default to zen)
    if ask_yes_no "Use linux-zen kernel for better performance (recommended)?"; then
        package_lists+=("$REPO_DIR/packages/linux-zen-pacman.txt")
        print_info "Selected: linux-zen kernel"
    else
        package_lists+=("$REPO_DIR/packages/linux-stable-pacman.txt")
        print_info "Selected: linux-stable kernel"
    fi

    # CPU-specific packages
    case "$CPU_VENDOR" in
        "intel")
            package_lists+=("$REPO_DIR/packages/intel-cpu-pacman.txt")
            print_info "Adding Intel CPU packages"
            ;;
        "amd")
            package_lists+=("$REPO_DIR/packages/amd-cpu-pacman.txt")
            print_info "Adding AMD CPU packages"
            ;;
        *)
            print_warning "Unknown CPU vendor: $CPU_VENDOR - skipping CPU-specific packages"
            ;;
    esac

    # GPU-specific packages
    case "$GPU_TYPE" in
        "nvidia"|"hybrid-nvidia")
            package_lists+=("$REPO_DIR/packages/nvidia-gpu-pacman.txt")
            print_info "Adding NVIDIA GPU packages"
            ;;
        "amd"|"hybrid-amd")
            package_lists+=("$REPO_DIR/packages/amd-gpu-pacman.txt")
            print_info "Adding AMD GPU packages"
            ;;
        "intel")
            package_lists+=("$REPO_DIR/packages/intel-gpu-pacman.txt")
            print_info "Adding Intel GPU packages"
            ;;
        *)
            print_warning "Unknown GPU type: $GPU_TYPE - skipping GPU-specific packages"
            ;;
    esac

    # Platform-specific packages
    case "$PLATFORM" in
        "laptop")
            package_lists+=("$REPO_DIR/packages/laptop-pacman.txt")
            print_info "Adding laptop packages (power management)"
            ;;
    esac

    # Vendor-specific packages
    case "$LAPTOP_BRAND" in
        "thinkpad")
            package_lists+=("$REPO_DIR/packages/thinkpad-pacman.txt")
            print_info "Adding ThinkPad packages"
            ;;
    esac

    # Count total packages
    for list in "${package_lists[@]}"; do
        if [[ -f "$list" ]]; then
            total_packages=$((total_packages + $(grep -c . "$list")))
        fi
    done

    print_info "Installing $total_packages packages from ${#package_lists[@]} package lists..."

    # Install packages from all lists
    for list in "${package_lists[@]}"; do
        if [[ -f "$list" ]]; then
            print_info "Installing packages from $(basename "$list")..."
            sudo pacman -S --needed --noconfirm - < "$list"
        else
            print_warning "Package list not found: $list"
        fi
    done

    print_success "Hardware-aware package installation completed"
}

install_aur_packages() {
    print_header "Installing AUR packages"

    AUR_PKGLIST="$REPO_DIR/packages/base-aur.txt"

    if [[ ! -f "$AUR_PKGLIST" ]]; then
        print_error "AUR package list not found: $AUR_PKGLIST"
        return 1
    fi

    # Check if paru is available
    if ! command -v paru &> /dev/null; then
        print_error "paru not found. Installing paru first..."

        # Install base-devel if not present
        sudo pacman -S --needed --noconfirm base-devel git

        # Clone and build paru
        cd /tmp || { print_error "Failed to change to /tmp directory"; return 1; }
        if [[ -d "paru" ]]; then
            print_info "Removing existing paru build directory"
            rm -rf paru
        fi

        if ! git clone https://aur.archlinux.org/paru.git; then
            print_error "Failed to clone paru repository"
            return 1
        fi

        cd paru || { print_error "Failed to enter paru directory"; return 1; }

        if ! makepkg -si --noconfirm; then
            print_error "Failed to build paru"
            cd "$REPO_DIR"
            return 1
        fi

        cd "$REPO_DIR" || { print_error "Failed to return to repo directory"; return 1; }
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

    # Validate paths
    [[ -d "$REPO_DIR/config" ]] || {
        print_error "Repository config directory not found: $REPO_DIR/config"
        return 1
    }

    local copied=0 skipped=0 failed=0

    # Dynamic config directory discovery
    local config_dirs=()
    while IFS= read -r -d '' dir; do
        [[ -d "$dir" ]] && config_dirs+=("$dir")
    done < <(find "$REPO_DIR/config" -mindepth 1 -maxdepth 1 -type d -print0)

    if [[ ${#config_dirs[@]} -eq 0 ]]; then
        print_error "No config directories found in $REPO_DIR/config"
        return 1
    fi

    print_info "Found ${#config_dirs[@]} config directories to process"

    # Process each config directory
    for src_dir in "${config_dirs[@]}"; do
        local dir_name=$(basename "$src_dir")
        local dst_dir="$CONFIG_DIR/$dir_name"

        print_info "Processing $dir_name directory..."

        # Create destination directory
        if ! mkdir -p "$dst_dir"; then
            print_error "Failed to create directory: $dst_dir"
            failed=$((failed + 1))
            continue
        fi

        # Find and copy all files in this directory
        local files=()
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$src_dir" -type f -print0)

        if [[ ${#files[@]} -eq 0 ]]; then
            print_info "No files found in $dir_name directory"
            continue
        fi

        # Copy each file
        for src_file in "${files[@]}"; do
            local rel_path="${src_file#$src_dir/}"
            local dst_file="$dst_dir/$rel_path"

            # Create subdirectories if needed
            local dst_subdir=$(dirname "$dst_file")
            if [[ "$dst_subdir" != "$dst_dir" ]]; then
                if ! mkdir -p "$dst_subdir"; then
                    print_error "Failed to create subdirectory: $dst_subdir"
                    failed=$((failed + 1))
                    continue
                fi
            fi

            # Backup existing file
            if [[ -f "$dst_file" ]]; then
                local backup="$dst_file.bak.$(date +%Y%m%d_%H%M%S)"
                if cp "$dst_file" "$backup"; then
                    print_info "Backed up: $(basename "$dst_file")"
                else
                    print_error "Failed to backup: $dst_file"
                    failed=$((failed + 1))
                    continue
                fi
            fi

            # Copy the file
            if cp "$src_file" "$dst_file"; then
                local dest_display="${dst_file/#$HOME/~}"
                print_success "Migrated: $rel_path → $dest_display"
                copied=$((copied + 1))
            else
                print_error "Failed to copy: $src_file → $dst_file"
                failed=$((failed + 1))
            fi
        done
    done

    # Copy wallpapers with error handling
    if [[ -d "$REPO_DIR/wallpapers" ]]; then
        print_info "Processing wallpapers..."

        if ! mkdir -p "$HOME/Pictures/wallpapers"; then
            print_error "Failed to create wallpapers directory"
            failed=$((failed + 1))
        else
            local wallpaper_files=()
            while IFS= read -r -d '' wallpaper; do
                [[ -f "$wallpaper" ]] && wallpaper_files+=("$wallpaper")
            done < <(find "$REPO_DIR/wallpapers" -maxdepth 1 -type f -print0)

            for wallpaper in "${wallpaper_files[@]}"; do
                if cp "$wallpaper" "$HOME/Pictures/wallpapers/"; then
                    print_success "Copied wallpaper: $(basename "$wallpaper")"
                    copied=$((copied + 1))
                else
                    print_error "Failed to copy wallpaper: $(basename "$wallpaper")"
                    failed=$((failed + 1))
                fi
            done
        fi
    else
        print_info "No wallpapers directory found, skipping wallpaper migration"
    fi

    # Migration summary
    print_info "Migration complete: $copied copied, $skipped skipped, $failed failed"

    if [[ $failed -gt 0 ]]; then
        print_error "Some files failed to migrate - check the errors above"
        return 1
    fi

    return 0
}

install_pywal_scripts() {
    print_header "Installing pywal integration scripts"

    # Create .local/bin directory with error handling
    if [[ ! -d "$HOME/.local/bin" ]]; then
        if mkdir -p "$HOME/.local/bin"; then
            print_success "Created ~/.local/bin directory"
        else
            print_error "Failed to create ~/.local/bin directory"
            return 1
        fi
    fi

    # Validate pywal integration directory exists
    if [[ ! -d "$REPO_DIR/scripts/pywal-integration" ]]; then
        print_info "No pywal integration scripts directory found"
        return 0
    fi

    local installed=0 failed=0

    print_info "Installing pywal integration scripts..."

    # Use arrays instead of subshells to fix variable persistence
    local scripts=()
    while IFS= read -r -d '' script; do
        [[ -f "$script" ]] && scripts+=("$script")
    done < <(find "$REPO_DIR/scripts/pywal-integration" -type f -print0)

    if [[ ${#scripts[@]} -eq 0 ]]; then
        print_info "No scripts found in pywal-integration directory"
        return 0
    fi

    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        local dest="$HOME/.local/bin/$script_name"

        # Backup existing script
        if [[ -f "$dest" ]]; then
            local backup="$dest.bak.$(date +%Y%m%d_%H%M%S)"
            if cp "$dest" "$backup"; then
                print_info "Backed up existing: $script_name"
            else
                print_error "Failed to backup: $script_name"
                failed=$((failed + 1))
                continue
            fi
        fi

        # Copy script
        if ! cp "$script" "$dest"; then
            print_error "Failed to copy: $script_name"
            failed=$((failed + 1))
            continue
        fi

        # Make executable
        if chmod +x "$dest"; then
            print_success "Installed: $script_name → ~/.local/bin/"
            installed=$((installed + 1))
        else
            print_error "Failed to make executable: $script_name"
            failed=$((failed + 1))
        fi
    done

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        # Check if the line already exists in .bashrc
        if ! grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            print_info "Adding ~/.local/bin to PATH in ~/.bashrc"
            if echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"; then
                print_success "Added ~/.local/bin to PATH"
            else
                print_error "Failed to update .bashrc"
                failed=$((failed + 1))
            fi
        else
            print_info "~/.local/bin PATH entry already exists in ~/.bashrc"
        fi
    else
        print_info "~/.local/bin already in current PATH"
    fi

    # Summary
    print_info "Installation complete: $installed installed, $failed failed"

    if [[ $failed -gt 0 ]]; then
        print_error "Some pywal scripts failed to install"
        return 1
    fi

    return 0
}

initialize_pywal() {
    print_header "Initializing pywal theme system"

    # Check if pywal is available (should be installed via AUR packages)
    if ! command -v wal &> /dev/null; then
        print_error "pywal not found. Make sure python-pywal16 was installed from AUR."
        return 1
    fi

    # Find a wallpaper to initialize pywal with
    local default_wallpaper=""
    local wallpaper_dirs=(
        "$HOME/Pictures/wallpapers"
        "$HOME/Pictures"
        "$REPO_DIR/config/wallpapers"
        "/usr/share/pixmaps"
        "/usr/share/backgrounds"
    )

    # Look for wallpapers in common directories
    for dir in "${wallpaper_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Find first suitable wallpaper (common image formats)
            default_wallpaper=$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | head -1)
            if [[ -n "$default_wallpaper" ]]; then
                break
            fi
        fi
    done

    # If no wallpaper found, create a simple solid color wallpaper
    if [[ -z "$default_wallpaper" ]]; then
        print_info "No wallpaper found, creating default solid color wallpaper..."
        mkdir -p "$HOME/Pictures/wallpapers"
        default_wallpaper="$HOME/Pictures/wallpapers/default.png"

        # Create a simple solid color wallpaper using ImageMagick if available
        if command -v convert &> /dev/null; then
            convert -size 1920x1080 xc:'#2d3748' "$default_wallpaper"
            print_success "Created default wallpaper: $default_wallpaper"
        else
            print_error "No wallpaper found and ImageMagick not available to create one."
            print_info "Please install ImageMagick or place a wallpaper in ~/Pictures/wallpapers/"
            return 1
        fi
    fi

    # Initialize pywal with the found/created wallpaper
    print_info "Initializing pywal with wallpaper: $default_wallpaper"
    wal -i "$default_wallpaper" -n

    # Verify pywal initialization
    if [[ -f "$HOME/.cache/wal/colors.json" ]]; then
        print_success "Pywal initialized successfully"

        # Update waybar colors if the script exists
        if [[ -x "$HOME/.local/bin/waybar-pywal-update" ]]; then
            print_info "Updating waybar with pywal colors..."
            "$HOME/.local/bin/waybar-pywal-update"
        fi
    else
        print_error "Pywal initialization failed"
        return 1
    fi
}

copy_system_files() {
    print_header "Copying hardware-specific system configuration files"

    # Load hardware detection results safely
    local hw_file="/tmp/hardware-detection.env"
    if ! safe_load_hw_file "$hw_file"; then
        print_error "Failed to load hardware detection results safely"
        return 1
    fi

    local copied_configs=0

    # Copy NVIDIA modprobe.d config only for NVIDIA systems
    if [[ "$GPU_TYPE" == "nvidia" ]] && [[ -f "$REPO_DIR/system/modprobe.d/nvidia.conf" ]]; then
        print_info "NVIDIA GPU detected - copying NVIDIA modprobe.d configuration..."
        if [[ -f "/etc/modprobe.d/nvidia.conf" ]]; then
            print_info "Backing up existing: /etc/modprobe.d/nvidia.conf"
            sudo cp "/etc/modprobe.d/nvidia.conf" "/etc/modprobe.d/nvidia.conf.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        sudo cp "$REPO_DIR/system/modprobe.d/nvidia.conf" "/etc/modprobe.d/"
        print_success "Copied: nvidia.conf → /etc/modprobe.d/"
        copied_configs=$((copied_configs + 1))
    else
        print_info "Non-NVIDIA system - skipping NVIDIA modprobe.d configuration"
    fi

    # Copy ThinkPad modprobe.d config only for ThinkPad systems
    if [[ "$LAPTOP_BRAND" == "thinkpad" ]] && [[ -f "$REPO_DIR/system/modprobe.d/thinkpad_acpi.conf" ]]; then
        print_info "ThinkPad detected - copying ThinkPad ACPI modprobe.d configuration..."
        if [[ -f "/etc/modprobe.d/thinkpad_acpi.conf" ]]; then
            print_info "Backing up existing: /etc/modprobe.d/thinkpad_acpi.conf"
            sudo cp "/etc/modprobe.d/thinkpad_acpi.conf" "/etc/modprobe.d/thinkpad_acpi.conf.bak.$(date +%Y%m%d_%H%M%S)"
        fi
        sudo cp "$REPO_DIR/system/modprobe.d/thinkpad_acpi.conf" "/etc/modprobe.d/"
        print_success "Copied: thinkpad_acpi.conf → /etc/modprobe.d/"
        copied_configs=$((copied_configs + 1))
    else
        print_info "Non-ThinkPad system - skipping ThinkPad ACPI modprobe.d configuration"
    fi

    # Copy other universal modprobe.d configs (blacklist-ucsi.conf, etc.)
    if [[ -d "$REPO_DIR/system/modprobe.d" ]]; then
        local universal_configs=()
        while IFS= read -r -d '' file; do
            universal_configs+=("$file")
        done < <(find "$REPO_DIR/system/modprobe.d" -name "*.conf" -type f ! -name "nvidia.conf" ! -name "thinkpad_acpi.conf" -print0)

        for file in "${universal_configs[@]}"; do
            local filename=$(basename "$file")
            print_info "Copying universal configuration: $filename"
            if [[ -f "/etc/modprobe.d/$filename" ]]; then
                print_info "Backing up existing: /etc/modprobe.d/$filename"
                sudo cp "/etc/modprobe.d/$filename" "/etc/modprobe.d/$filename.bak.$(date +%Y%m%d_%H%M%S)"
            fi
            sudo cp "$file" "/etc/modprobe.d/"
            print_success "Copied: $filename → /etc/modprobe.d/"
            copied_configs=$((copied_configs + 1))
        done
    fi

    # Regenerate initramfs if any configs were copied
    if [[ $copied_configs -gt 0 ]]; then
        print_info "Regenerating initramfs for kernel module changes..."
        sudo mkinitcpio -P
        print_success "Initramfs regenerated"
    else
        print_info "No hardware-specific configurations to apply"
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
    for service in pipewire pipewire-pulse wireplumber; do
        if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
            print_info "User service $service is already enabled"
        else
            if systemctl --user enable "$service" 2>/dev/null; then
                print_success "Enabled user service: $service"
            else
                print_error "Failed to enable user service: $service (may not be installed yet)"
            fi
        fi
    done

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
    print_header "AGNOSIS ARCH BOOTSTRAP SCRIPT (TEST BRANCH)"
    echo "Repository: $REPO_DIR"
    echo "Configuration: $CONFIG_DIR"
    echo ""
    echo "This script will help you set up your Arch system with:"
    echo "  1. Make all scripts executable"
    echo "  2. Hardware-aware package installation (adaptive to your system)"
    echo "  3. Install AUR packages"
    echo "  4. Create necessary directories"
    echo "  5. Migrate configuration files"
    echo "  6. Install pywal integration scripts"
    echo "  7. Initialize pywal with wallpaper and generate color schemes"
    echo "  8. Copy hardware-specific system files (NVIDIA/ThinkPad configs only when detected)"
    echo "  9. Enable system services"
    echo " 10. Reload configurations"
    echo ""
    echo "Hardware detection will automatically select appropriate packages."
    echo "You will be prompted at each major step."
    echo ""
    
    if ! ask_yes_no "Do you want to continue?"; then
        print_info "Bootstrap cancelled"
        exit 0
    fi
    
    # Step 1: Make scripts executable
    echo ""
    if ask_yes_no "Make all scripts executable?"; then
        chmod_all_scripts || print_warning "Script permission changes completed with some errors"
    else
        print_info "Skipped making scripts executable"
    fi
    
    # Step 2: Install hardware-detected packages
    echo ""
    echo "Hardware-aware package installation:"
    echo "  - Base system packages (~47 packages)"
    echo "  - Hardware-specific drivers (automatically detected)"
    echo "  - Hyprland desktop environment"
    echo "  - Essential tools (neovim, ranger, btop, chromium)"
    echo "  - Platform-specific packages (laptop/desktop)"
    echo ""
    if ask_yes_no "Install packages with hardware detection?"; then
        install_packages
    else
        print_info "Skipped package installation"
    fi

    # Step 3: Install minimal AUR packages
    echo ""
    echo "Minimal AUR packages (~2 packages vs 19 full list):"
    if [[ -f "$REPO_DIR/packages/base-aur.txt" ]]; then
        cat "$REPO_DIR/packages/base-aur.txt" | sed 's/^/  - /'
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
        migrate_config_files || print_warning "Config file migration completed with some errors"
    else
        print_info "Skipped config file migration"
    fi

    # Step 6: Install pywal scripts
    echo ""
    echo "Pywal integration scripts:"
    echo "  - fuzzel-pywal-update (dynamic fuzzel theming)"
    echo "  - hyprland-pywal-update (dynamic hyprland theming)"
    echo "  - mako-pywal-update (dynamic notification theming)"
    echo "  - waybar-pywal-update (dynamic waybar theming)"
    echo "  - wallpaper (wallpaper management script)"
    echo ""
    if ask_yes_no "Install pywal integration scripts to ~/.local/bin/?"; then
        install_pywal_scripts || print_warning "Pywal script installation completed with some errors"
    else
        print_info "Skipped pywal script installation"
    fi

    # Step 7: Initialize pywal color schemes
    echo ""
    echo "Pywal initialization:"
    echo "  - Set up initial wallpaper (creates default if none found)"
    echo "  - Generate color schemes for all components"
    echo "  - Create waybar-colors.css for waybar theming"
    echo "  - Initialize pywal cache directory"
    echo ""
    if ask_yes_no "Initialize pywal with wallpaper and generate color schemes?"; then
        initialize_pywal || print_warning "Pywal initialization completed with some errors"
    else
        print_info "Skipped pywal initialization"
    fi

    # Step 8: Copy system files
    echo ""
    echo "System files to copy:"
    echo "  - nvidia.conf (NVIDIA driver settings for Wayland)"
    echo "  - blacklist-ucsi.conf (fix ACPI errors)"
    echo "  - thinkpad_acpi.conf (ThinkPad fan control)"
    echo ""
    if ask_yes_no "Copy system configuration files (requires sudo)?"; then
        copy_system_files || print_warning "System file configuration completed with some errors"
    else
        print_info "Skipped system file configuration"
    fi

    # Step 9: Enable services
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
    
    # Step 10: Reload configurations
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