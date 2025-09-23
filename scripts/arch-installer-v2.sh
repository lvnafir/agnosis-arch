#!/bin/bash
# Evidence-Based Arch Linux Installer
# Implements only verified, working functionality with proper error handling

set -euo pipefail  # Strict error handling

# Global configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/arch-install.log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Global variables (explicitly declared)
declare TARGET_DISK=""
declare BOOT_MODE=""
declare HOSTNAME=""
declare USERNAME=""
declare TIMEZONE=""
declare ROOT_PARTITION=""
declare EFI_PARTITION=""
declare SWAP_PARTITION=""
declare SWAP_SIZE=""
declare LOCALE=""
declare MENU_SELECTION=""

# Selected packages (avoid variable scoping issues)
declare KERNEL_PKG=""
declare NETWORK_PKGS=""
declare FILE_MANAGER=""
declare TEXT_EDITOR=""
declare SYSTEM_MONITOR=""
declare WEB_BROWSER=""
declare CPU_MICROCODE=""
declare GPU_DRIVERS=""
declare ENABLE_SSH=""
declare PLATFORM=""

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}===============================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}===============================================${NC}" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    print_error "Installation failed: $1"
    print_error "Check log file: $LOG_FILE"
    exit 1
}

# Menu selection with validation (using global variable to avoid return code issues)
select_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice

    echo -e "\n${YELLOW}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[i]}"
    done

    while true; do
        read -p "Select option (1-${#options[@]}): " choice || {
            print_error "Read failed"
            return 1
        }
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
            MENU_SELECTION=$((choice-1))
            return 0
        else
            print_error "Invalid choice. Please select 1-${#options[@]}"
        fi
    done
}

# Validate installation environment
validate_environment() {
    print_header "Environment Validation"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "Must run as root (use sudo)"
    fi

    # Verify essential tools exist
    local tools=("pacstrap" "arch-chroot" "genfstab" "lsblk" "parted")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            error_exit "Required tool missing: $tool"
        fi
    done
    print_success "All required tools available"

    # Test internet connectivity (multiple attempts)
    local test_hosts=("archlinux.org" "8.8.8.8" "1.1.1.1")
    local connected=false
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            connected=true
            break
        fi
    done

    if ! $connected; then
        error_exit "No internet connectivity. Configure network first."
    fi
    print_success "Internet connectivity verified"

    # Initialize pacman keys (CRITICAL - was missing) with retry
    print_info "Initializing pacman keyring..."
    local retry_count=0
    while [[ $retry_count -lt 3 ]]; do
        if pacman-key --init && pacman-key --populate archlinux; then
            print_success "Pacman keyring initialized"
            break
        else
            ((retry_count++))
            if [[ $retry_count -lt 3 ]]; then
                print_warning "Keyring initialization failed, retrying ($retry_count/3)..."
                sleep 2
            else
                error_exit "Failed to initialize pacman keys after 3 attempts"
            fi
        fi
    done

    # Sync package databases
    print_info "Syncing package databases..."
    pacman -Sy || error_exit "Failed to sync package databases"
    print_success "Package databases synced"

    # Detect boot mode
    if [[ -d /sys/firmware/efi ]]; then
        BOOT_MODE="UEFI"
        print_success "UEFI boot mode detected"
    else
        BOOT_MODE="BIOS"
        print_success "BIOS boot mode detected"
    fi

    # Set system clock
    timedatectl set-ntp true || error_exit "Failed to sync system clock"
    print_success "System clock synchronized"
}

# Hardware detection with evidence gathering
detect_hardware() {
    print_header "Hardware Detection"

    # CPU detection
    local cpu_vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
    case "$cpu_vendor" in
        "GenuineIntel")
            CPU_MICROCODE="intel-ucode"
            print_success "Intel CPU detected"
            ;;
        "AuthenticAMD")
            CPU_MICROCODE="amd-ucode"
            print_success "AMD CPU detected"
            ;;
        *)
            CPU_MICROCODE=""
            print_warning "Unknown CPU vendor: $cpu_vendor"
            ;;
    esac

    # GPU detection (simplified for reliability)
    local gpu_info
    gpu_info=$(lspci | grep -iE "(vga|3d|display)" || true)

    if echo "$gpu_info" | grep -iq nvidia; then
        GPU_DRIVERS="nvidia nvidia-utils"
        print_success "NVIDIA GPU detected"
    elif echo "$gpu_info" | grep -iqE "\\b(amd|ati|radeon)\\b"; then
        GPU_DRIVERS="mesa vulkan-radeon"
        print_success "AMD GPU detected"
    elif echo "$gpu_info" | grep -iq intel; then
        GPU_DRIVERS="mesa vulkan-intel"
        print_success "Intel GPU detected"
    else
        GPU_DRIVERS="mesa"
        print_warning "Generic GPU drivers selected"
    fi

    # Platform detection
    if ls /sys/class/power_supply/BAT* &>/dev/null; then
        PLATFORM="laptop"
        print_success "Laptop platform detected"
    else
        PLATFORM="desktop"
        print_success "Desktop platform detected"
    fi
}

# Validate package existence
validate_packages() {
    local packages=("$@")
    local missing_packages=()

    print_info "Validating package availability..."
    for pkg in "${packages[@]}"; do
        if ! pacman -Si "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_error "Missing packages: ${missing_packages[*]}"
        return 1
    fi

    print_success "All packages available"
    return 0
}

# Package selection with user preferences
configure_packages() {
    print_header "Package Configuration"

    # Kernel selection
    select_menu "Choose kernel:" \
        "linux-zen (optimized)" \
        "linux (stable)" \
        "linux-lts (long-term)"

    case $MENU_SELECTION in
        0) KERNEL_PKG="linux-zen" ;;
        1) KERNEL_PKG="linux" ;;
        2) KERNEL_PKG="linux-lts" ;;
        *) error_exit "Invalid kernel selection" ;;
    esac

    # Network management
    select_menu "Choose network management:" \
        "iwd + dhcpcd (minimal)" \
        "NetworkManager (full-featured)"

    case $MENU_SELECTION in
        0) NETWORK_PKGS="iwd dhcpcd" ;;
        1) NETWORK_PKGS="networkmanager wpa_supplicant" ;;
        *) error_exit "Invalid network selection" ;;
    esac

    # File manager
    select_menu "Choose file manager:" \
        "ranger (terminal, vim-like)" \
        "broot (modern terminal)" \
        "nnn (minimal terminal)"

    case $MENU_SELECTION in
        0) FILE_MANAGER="ranger" ;;
        1) FILE_MANAGER="broot" ;;
        2) FILE_MANAGER="nnn" ;;
        *) error_exit "Invalid file manager selection" ;;
    esac

    # Text editor
    select_menu "Choose text editor:" \
        "nano (simple)" \
        "vim (powerful)" \
        "neovim (modern)"

    case $MENU_SELECTION in
        0) TEXT_EDITOR="nano" ;;
        1) TEXT_EDITOR="vim" ;;
        2) TEXT_EDITOR="neovim" ;;
        *) error_exit "Invalid text editor selection" ;;
    esac

    # System monitor
    select_menu "Choose system monitor:" \
        "btop (modern)" \
        "htop (classic)" \
        "top (minimal)"

    case $MENU_SELECTION in
        0) SYSTEM_MONITOR="btop" ;;
        1) SYSTEM_MONITOR="htop" ;;
        2) SYSTEM_MONITOR="top" ;;
        *) error_exit "Invalid system monitor selection" ;;
    esac

    # Web browser
    select_menu "Choose terminal browser:" \
        "links (recommended)" \
        "lynx (classic)" \
        "w3m (advanced)"

    case $MENU_SELECTION in
        0) WEB_BROWSER="links" ;;
        1) WEB_BROWSER="lynx" ;;
        2) WEB_BROWSER="w3m" ;;
        *) error_exit "Invalid browser selection" ;;
    esac

    # SSH server
    select_menu "SSH server:" \
        "Install and enable" \
        "Install only" \
        "Don't install"

    case $MENU_SELECTION in
        0) ENABLE_SSH="enable" ;;
        1) ENABLE_SSH="install" ;;
        2) ENABLE_SSH="no" ;;
        *) error_exit "Invalid SSH selection" ;;
    esac

    # Validate selected packages exist
    local test_packages=("$KERNEL_PKG" $NETWORK_PKGS "$FILE_MANAGER" "$TEXT_EDITOR" "$SYSTEM_MONITOR" "$WEB_BROWSER")
    if [[ -n "$CPU_MICROCODE" ]]; then
        test_packages+=("$CPU_MICROCODE")
    fi
    test_packages+=($GPU_DRIVERS)

    if ! validate_packages "${test_packages[@]}"; then
        error_exit "Some selected packages are not available"
    fi

    print_success "Package selection complete and validated"
}

# Storage configuration with safety checks
configure_storage() {
    print_header "Storage Configuration"

    # List available disks
    print_info "Available storage devices:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk

    # Disk selection with validation
    while true; do
        echo ""
        read -p "Enter target disk (e.g., sda, nvme0n1): " disk_name
        TARGET_DISK="/dev/$disk_name"

        if [[ -b "$TARGET_DISK" ]]; then
            break
        else
            print_error "Invalid disk: $TARGET_DISK"
        fi
    done

    # Safety confirmation
    print_warning "This will PERMANENTLY ERASE ALL DATA on $TARGET_DISK"
    lsblk "$TARGET_DISK"
    echo ""
    read -p "Type 'YES' to continue: " confirm
    if [[ "$confirm" != "YES" ]]; then
        error_exit "Installation cancelled by user"
    fi

    # Check if disk is mounted
    if mount | grep -q "$TARGET_DISK"; then
        print_error "Target disk $TARGET_DISK has mounted partitions:"
        mount | grep "$TARGET_DISK"
        error_exit "Unmount all partitions on $TARGET_DISK first"
    fi

    # Ask about swap partition
    select_menu "Swap partition configuration:" \
        "No swap partition" \
        "2GB swap partition" \
        "4GB swap partition" \
        "8GB swap partition" \
        "Custom size"

    case $MENU_SELECTION in
        0) SWAP_SIZE="" ;;
        1) SWAP_SIZE="2G" ;;
        2) SWAP_SIZE="4G" ;;
        3) SWAP_SIZE="8G" ;;
        4) read -p "Enter swap size (e.g., 1G, 512M): " SWAP_SIZE ;;
        *) error_exit "Invalid swap selection" ;;
    esac

    # Partitioning
    print_info "Partitioning $TARGET_DISK..."

    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        parted -s "$TARGET_DISK" mklabel gpt || error_exit "Failed to create GPT partition table"
        parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 513MiB || error_exit "Failed to create EFI partition"
        parted -s "$TARGET_DISK" set 1 esp on || error_exit "Failed to set ESP flag"

        if [[ -n "$SWAP_SIZE" ]]; then
            # Convert size to MB for calculations
            local swap_mb=$((${SWAP_SIZE%G} * 1024))
            parted -s "$TARGET_DISK" mkpart primary linux-swap 513MiB $((513 + swap_mb))MiB || error_exit "Failed to create swap partition"
            parted -s "$TARGET_DISK" mkpart primary ext4 $((513 + swap_mb))MiB 100% || error_exit "Failed to create root partition"
        else
            parted -s "$TARGET_DISK" mkpart primary ext4 513MiB 100% || error_exit "Failed to create root partition"
        fi

        # Handle different disk naming schemes
        if [[ "$TARGET_DISK" =~ nvme ]]; then
            EFI_PARTITION="${TARGET_DISK}p1"
            if [[ -n "$SWAP_SIZE" ]]; then
                SWAP_PARTITION="${TARGET_DISK}p2"
                ROOT_PARTITION="${TARGET_DISK}p3"
            else
                ROOT_PARTITION="${TARGET_DISK}p2"
            fi
        else
            EFI_PARTITION="${TARGET_DISK}1"
            if [[ -n "$SWAP_SIZE" ]]; then
                SWAP_PARTITION="${TARGET_DISK}2"
                ROOT_PARTITION="${TARGET_DISK}3"
            else
                ROOT_PARTITION="${TARGET_DISK}2"
            fi
        fi

        # Format partitions
        mkfs.fat -F32 "$EFI_PARTITION" || error_exit "Failed to format EFI partition"
        if [[ -n "$SWAP_SIZE" ]]; then
            mkswap "$SWAP_PARTITION" || error_exit "Failed to format swap partition"
        fi
        mkfs.ext4 -F "$ROOT_PARTITION" || error_exit "Failed to format root partition"

        # Mount filesystems
        mount "$ROOT_PARTITION" /mnt || error_exit "Failed to mount root partition"
        if [[ -n "$SWAP_SIZE" ]]; then
            swapon "$SWAP_PARTITION" || error_exit "Failed to enable swap"
        fi
        mkdir -p /mnt/boot || error_exit "Failed to create boot directory"
        mount "$EFI_PARTITION" /mnt/boot || error_exit "Failed to mount EFI partition"

    else
        # BIOS mode
        parted -s "$TARGET_DISK" mklabel msdos || error_exit "Failed to create MBR partition table"

        if [[ -n "$SWAP_SIZE" ]]; then
            # Convert size to MB for calculations
            local swap_mb=$((${SWAP_SIZE%G} * 1024))
            parted -s "$TARGET_DISK" mkpart primary linux-swap 1MiB $((1 + swap_mb))MiB || error_exit "Failed to create swap partition"
            parted -s "$TARGET_DISK" mkpart primary ext4 $((1 + swap_mb))MiB 100% || error_exit "Failed to create root partition"
            parted -s "$TARGET_DISK" set 2 boot on || error_exit "Failed to set boot flag"
        else
            parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100% || error_exit "Failed to create partition"
            parted -s "$TARGET_DISK" set 1 boot on || error_exit "Failed to set boot flag"
        fi

        if [[ "$TARGET_DISK" =~ nvme ]]; then
            if [[ -n "$SWAP_SIZE" ]]; then
                SWAP_PARTITION="${TARGET_DISK}p1"
                ROOT_PARTITION="${TARGET_DISK}p2"
            else
                ROOT_PARTITION="${TARGET_DISK}p1"
            fi
        else
            if [[ -n "$SWAP_SIZE" ]]; then
                SWAP_PARTITION="${TARGET_DISK}1"
                ROOT_PARTITION="${TARGET_DISK}2"
            else
                ROOT_PARTITION="${TARGET_DISK}1"
            fi
        fi

        if [[ -n "$SWAP_SIZE" ]]; then
            mkswap "$SWAP_PARTITION" || error_exit "Failed to format swap partition"
        fi
        mkfs.ext4 -F "$ROOT_PARTITION" || error_exit "Failed to format root partition"

        mount "$ROOT_PARTITION" /mnt || error_exit "Failed to mount root partition"
        if [[ -n "$SWAP_SIZE" ]]; then
            swapon "$SWAP_PARTITION" || error_exit "Failed to enable swap"
        fi
    fi

    print_success "Storage configuration complete"
}

# System installation with proper package management
install_system() {
    print_header "Installing Base System"

    # Build package list (explicit and validated)
    local packages=(
        "base" "$KERNEL_PKG" "linux-firmware"
        $NETWORK_PKGS  # Note: no quotes to split into separate arguments
        "$FILE_MANAGER" "$TEXT_EDITOR" "$SYSTEM_MONITOR" "$WEB_BROWSER"
        "sudo" "base-devel" "git" "man-db" "man-pages" "bash-completion"
        "less" "unzip" "zip" "rsync" "tree"
        "lshw" "dmidecode" "usbutils" "pciutils" "bind" "wget" "curl"
        "grub"  # Only implement GRUB for reliability
    )

    # Add CPU microcode if detected
    if [[ -n "$CPU_MICROCODE" ]]; then
        packages+=("$CPU_MICROCODE")
    fi

    # Add GPU drivers
    packages+=($GPU_DRIVERS)  # Note: no quotes to split

    # Add UEFI support
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        packages+=("efibootmgr")
    fi

    # Add SSH if requested
    if [[ "$ENABLE_SSH" != "no" ]]; then
        packages+=("openssh")
    fi

    # Add laptop packages
    if [[ "$PLATFORM" == "laptop" ]]; then
        packages+=("tlp" "acpi")
    fi

    print_info "Installing ${#packages[@]} packages: ${packages[*]}"

    # Install base system
    pacstrap /mnt "${packages[@]}" || error_exit "Failed to install packages"

    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Failed to generate fstab"

    # Validate fstab
    if [[ ! -s /mnt/etc/fstab ]]; then
        error_exit "Generated fstab is empty"
    fi

    print_success "Base system installed successfully"
}

# System configuration with proper variable handling
configure_system() {
    print_header "System Configuration"

    # Locale selection
    select_menu "Choose system locale:" \
        "en_US.UTF-8 (English - US)" \
        "en_GB.UTF-8 (English - UK)" \
        "de_DE.UTF-8 (German)" \
        "fr_FR.UTF-8 (French)" \
        "es_ES.UTF-8 (Spanish)" \
        "Custom locale"

    case $MENU_SELECTION in
        0) LOCALE="en_US.UTF-8" ;;
        1) LOCALE="en_GB.UTF-8" ;;
        2) LOCALE="de_DE.UTF-8" ;;
        3) LOCALE="fr_FR.UTF-8" ;;
        4) LOCALE="es_ES.UTF-8" ;;
        5) read -p "Enter locale (e.g., ja_JP.UTF-8): " LOCALE ;;
        *) error_exit "Invalid locale selection" ;;
    esac

    # Timezone selection
    select_menu "Choose timezone:" \
        "America/New_York (US East)" \
        "America/Chicago (US Central)" \
        "America/Denver (US Mountain)" \
        "America/Los_Angeles (US West)" \
        "Europe/London (UK)" \
        "Europe/Berlin (Germany)" \
        "Custom"

    case $MENU_SELECTION in
        0) TIMEZONE="America/New_York" ;;
        1) TIMEZONE="America/Chicago" ;;
        2) TIMEZONE="America/Denver" ;;
        3) TIMEZONE="America/Los_Angeles" ;;
        4) TIMEZONE="Europe/London" ;;
        5) TIMEZONE="Europe/Berlin" ;;
        6) read -p "Enter timezone (e.g., Asia/Tokyo): " TIMEZONE ;;
        *) error_exit "Invalid timezone selection" ;;
    esac

    # Hostname validation
    while true; do
        read -p "Enter hostname: " HOSTNAME
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]] && [[ ${#HOSTNAME} -le 63 ]] && [[ "$HOSTNAME" != "-"* ]] && [[ "$HOSTNAME" != *"-" ]]; then
            break
        else
            print_error "Invalid hostname. Use only letters, numbers, and hyphens. Max 63 characters."
        fi
    done

    # Get username (hostname already validated)
    read -p "Enter username: " USERNAME

    # Configure system in chroot (using explicit variable passing)
    print_info "Configuring system in chroot..."

    # Create configuration script to avoid variable scoping issues
    cat > /mnt/tmp/configure.sh << EOF
#!/bin/bash
set -euo pipefail

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Configure locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Configure pacman (enable multilib - was missing!)
cp /etc/pacman.conf /etc/pacman.conf.backup
sed -i '/^\[multilib\]/,/Include.*mirrorlist/ s/^#//' /etc/pacman.conf

# Initialize pacman in chroot (CRITICAL)
pacman-key --init
pacman-key --populate archlinux
pacman -Sy

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOL
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOL

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME

# Enable services based on network choice
if echo "$NETWORK_PKGS" | grep -q "networkmanager"; then
    systemctl enable NetworkManager.service
elif echo "$NETWORK_PKGS" | grep -q "iwd"; then
    systemctl enable iwd.service
    systemctl enable dhcpcd.service
fi

# Enable SSH if requested
if [[ "$ENABLE_SSH" == "enable" ]]; then
    systemctl enable sshd.service
fi

# Enable laptop services
if [[ "$PLATFORM" == "laptop" ]]; then
    systemctl enable tlp.service
fi
EOF

    chmod +x /mnt/tmp/configure.sh
    arch-chroot /mnt /tmp/configure.sh || error_exit "System configuration failed"
    rm /mnt/tmp/configure.sh

    # Set passwords (interactive, must be done separately)
    print_info "Setting root password:"
    arch-chroot /mnt passwd || error_exit "Failed to set root password"

    print_info "Setting user password for $USERNAME:"
    arch-chroot /mnt passwd "$USERNAME" || error_exit "Failed to set user password"

    print_success "System configuration complete"
}

# Bootloader installation (GRUB only for reliability)
install_bootloader() {
    print_header "Installing Bootloader"

    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || error_exit "GRUB UEFI installation failed"
    else
        arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK" || error_exit "GRUB BIOS installation failed"
    fi

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || error_exit "GRUB configuration failed"

    # Validate bootloader installation
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        if [[ ! -f /mnt/boot/EFI/GRUB/grubx64.efi ]]; then
            error_exit "GRUB EFI binary not found after installation"
        fi
    fi

    print_success "Bootloader installed successfully"
}

# Final validation
validate_installation() {
    print_header "Installation Validation"

    local errors=0

    # Check critical files
    local critical_files=(
        "/mnt/etc/fstab"
        "/mnt/etc/hostname"
        "/mnt/boot/grub/grub.cfg"
    )

    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Missing critical file: $file"
            ((errors++))
        fi
    done

    # Check user exists
    if ! arch-chroot /mnt id "$USERNAME" &>/dev/null; then
        print_error "User $USERNAME not found"
        ((errors++))
    fi

    # Check services are enabled
    if echo "$NETWORK_PKGS" | grep -q "networkmanager"; then
        if ! arch-chroot /mnt systemctl is-enabled NetworkManager.service &>/dev/null; then
            print_error "NetworkManager service not enabled"
            ((errors++))
        fi
    elif echo "$NETWORK_PKGS" | grep -q "iwd"; then
        if ! arch-chroot /mnt systemctl is-enabled iwd.service &>/dev/null; then
            print_error "iwd service not enabled"
            ((errors++))
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        error_exit "Installation validation failed with $errors errors"
    fi

    print_success "Installation validation passed"
}

# Cleanup and finish
finish_installation() {
    print_header "Installation Complete"

    # Display summary
    print_info "Installation Summary:"
    print_info "  Target: $TARGET_DISK ($BOOT_MODE mode)"
    print_info "  Kernel: $KERNEL_PKG"
    print_info "  Network: $NETWORK_PKGS"
    print_info "  Hostname: $HOSTNAME"
    print_info "  User: $USERNAME"
    print_info "  Timezone: $TIMEZONE"

    # Unmount filesystems
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        umount /mnt/boot || print_warning "Failed to unmount /mnt/boot"
    fi
    umount /mnt || print_warning "Failed to unmount /mnt"

    print_success "Installation completed successfully!"
    print_info "Log file saved to: $LOG_FILE"
    print_warning "Remove installation media and reboot"

    read -p "Reboot now? (y/n): " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy] ]]; then
        reboot
    fi
}

# Main execution flow
main() {
    print_header "Evidence-Based Arch Linux Installer"
    log "Installation started by $(whoami) at $(date)"

    validate_environment
    detect_hardware
    configure_packages
    configure_storage
    install_system
    configure_system
    install_bootloader
    validate_installation
    finish_installation

    log "Installation completed successfully"
}

# Run main function with error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi