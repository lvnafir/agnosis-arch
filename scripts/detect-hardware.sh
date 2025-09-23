#!/bin/bash

# Hardware Detection Script for Agnosis Arch
# Detects CPU vendor, GPU type, platform, and vendor-specific features
# Returns JSON-like output for easy parsing by bootstrap script

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect CPU vendor
detect_cpu() {
    local cpu_vendor=""
    if [[ -f /proc/cpuinfo ]]; then
        cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
        case "$cpu_vendor" in
            "GenuineIntel") echo "intel" ;;
            "AuthenticAMD") echo "amd" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Detect GPU hardware
detect_gpu() {
    local gpu_info=""
    local nvidia_found=false
    local amd_found=false
    local intel_found=false

    if command -v lspci &> /dev/null; then
        gpu_info=$(lspci | grep -iE "(vga|3d|display)")

        if echo "$gpu_info" | grep -iq "nvidia"; then
            nvidia_found=true
        fi

        if echo "$gpu_info" | grep -iqE "(amd|ati|radeon)"; then
            amd_found=true
        fi

        if echo "$gpu_info" | grep -iq "intel"; then
            intel_found=true
        fi
    fi

    # Determine primary GPU configuration
    if $nvidia_found && $intel_found; then
        echo "hybrid-nvidia"
    elif $amd_found && $intel_found; then
        echo "hybrid-amd"
    elif $nvidia_found; then
        echo "nvidia"
    elif $amd_found; then
        echo "amd"
    elif $intel_found; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# Detect platform type (laptop vs desktop)
detect_platform() {
    local chassis_type=""

    if command -v dmidecode &> /dev/null; then
        chassis_type=$(dmidecode -s chassis-type 2>/dev/null | head -1)
        case "$chassis_type" in
            "Notebook"|"Laptop"|"Portable"|"Hand Held"|"Sub Notebook") echo "laptop" ;;
            "Desktop"|"Low Profile Desktop"|"Tower"|"Mini Tower") echo "desktop" ;;
            "All in One"|"Stick PC") echo "desktop" ;;
            *)
                # Fallback: check for battery
                if ls /sys/class/power_supply/BAT* &>/dev/null; then
                    echo "laptop"
                else
                    echo "desktop"
                fi
                ;;
        esac
    else
        # Fallback: check for battery
        if ls /sys/class/power_supply/BAT* &>/dev/null; then
            echo "laptop"
        else
            echo "desktop"
        fi
    fi
}

# Detect vendor-specific features
detect_vendor() {
    local vendor=""
    local model=""

    if command -v dmidecode &> /dev/null; then
        vendor=$(dmidecode -s system-manufacturer 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]')
        model=$(dmidecode -s system-product-name 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]')

        case "$vendor" in
            *"lenovo"*)
                if echo "$model" | grep -q "thinkpad"; then
                    echo "thinkpad"
                else
                    echo "lenovo"
                fi
                ;;
            *"dell"*) echo "dell" ;;
            *"hp"*|*"hewlett"*) echo "hp" ;;
            *"asus"*) echo "asus" ;;
            *"msi"*) echo "msi" ;;
            *"acer"*) echo "acer" ;;
            *) echo "generic" ;;
        esac
    else
        echo "generic"
    fi
}

# Detect country for mirror optimization
detect_country() {
    local country=""

    # Try to detect from locale
    if [[ -n "$LANG" ]]; then
        case "$LANG" in
            *"US"*|*"us"*) echo "US" ;;
            *"GB"*|*"gb"*) echo "GB" ;;
            *"DE"*|*"de"*) echo "DE" ;;
            *"FR"*|*"fr"*) echo "FR" ;;
            *"JP"*|*"jp"*) echo "JP" ;;
            *"CN"*|*"cn"*) echo "CN" ;;
            *) echo "US" ;; # Default fallback
        esac
    else
        echo "US" # Default fallback
    fi
}

# Check for specific hardware features
detect_features() {
    local features=()

    # Check for ThinkPad-specific features
    if [[ -f /proc/acpi/ibm/fan ]]; then
        features+=("thinkpad_fan_control")
    fi

    # Check for discrete NVIDIA with Optimus
    if lspci | grep -iq nvidia && [[ -d /sys/class/drm/card0 ]]; then
        if ls /sys/class/drm/ | grep -q "card1"; then
            features+=("nvidia_optimus")
        fi
    fi

    # Check for AMD hybrid graphics
    if lspci | grep -iq amd && lspci | grep -iq intel; then
        features+=("amd_hybrid")
    fi

    # Check for Thunderbolt
    if lspci | grep -iq thunderbolt; then
        features+=("thunderbolt")
    fi

    # Check for touchscreen
    if xinput list 2>/dev/null | grep -iq touch; then
        features+=("touchscreen")
    fi

    # Check for fingerprint reader
    if lsusb | grep -iq fingerprint; then
        features+=("fingerprint")
    fi

    # Return as comma-separated string
    IFS=','
    echo "${features[*]}"
}

# Generate hardware profile
generate_profile() {
    local output_format="${1:-human}"

    local cpu_vendor=$(detect_cpu)
    local gpu_type=$(detect_gpu)
    local platform=$(detect_platform)
    local vendor=$(detect_vendor)
    local country=$(detect_country)
    local features=$(detect_features)

    if [[ "$output_format" == "json" ]]; then
        cat << EOF
{
    "cpu_vendor": "$cpu_vendor",
    "gpu_type": "$gpu_type",
    "platform": "$platform",
    "vendor": "$vendor",
    "country": "$country",
    "features": "$features",
    "detection_time": "$(date -Iseconds)"
}
EOF
    elif [[ "$output_format" == "env" ]]; then
        cat << EOF
CPU_VENDOR="$cpu_vendor"
GPU_TYPE="$gpu_type"
PLATFORM="$platform"
VENDOR="$vendor"
COUNTRY="$country"
FEATURES="$features"
DETECTION_TIME="$(date -Iseconds)"
EOF
    else
        # Human-readable format
        echo "Hardware Detection Results:"
        echo "=========================="
        echo "CPU Vendor:    $cpu_vendor"
        echo "GPU Type:      $gpu_type"
        echo "Platform:      $platform"
        echo "Vendor:        $vendor"
        echo "Country:       $country"
        echo "Features:      $features"
        echo "Detected:      $(date)"
    fi
}

# Validate detected hardware and provide recommendations
validate_hardware() {
    local cpu_vendor=$(detect_cpu)
    local gpu_type=$(detect_gpu)
    local platform=$(detect_platform)

    print_info "Validating hardware detection..."

    # CPU validation
    case "$cpu_vendor" in
        "intel")
            print_success "Intel CPU detected - will install intel-ucode"
            ;;
        "amd")
            print_success "AMD CPU detected - will install amd-ucode"
            ;;
        "unknown")
            print_warning "Unknown CPU vendor - will use generic configuration"
            ;;
    esac

    # GPU validation
    case "$gpu_type" in
        "nvidia")
            print_success "NVIDIA GPU detected - will install nvidia drivers"
            ;;
        "amd")
            print_success "AMD GPU detected - will install mesa/amdgpu drivers"
            ;;
        "intel")
            print_success "Intel GPU detected - will install mesa/intel drivers"
            ;;
        "hybrid-nvidia")
            print_success "NVIDIA hybrid graphics detected - will configure Optimus"
            ;;
        "hybrid-amd")
            print_success "AMD hybrid graphics detected - will configure switchable graphics"
            ;;
        "unknown")
            print_warning "Unknown GPU - will use generic graphics configuration"
            ;;
    esac

    # Platform validation
    case "$platform" in
        "laptop")
            print_success "Laptop detected - will install power management tools"
            ;;
        "desktop")
            print_success "Desktop detected - will use performance-oriented configuration"
            ;;
    esac
}

# Main function
main() {
    local output_format="human"
    local validate_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                output_format="json"
                shift
                ;;
            --env)
                output_format="env"
                shift
                ;;
            --validate)
                validate_only=true
                shift
                ;;
            --help|-h)
                cat << EOF
Hardware Detection Script for Agnosis Arch

Usage: $0 [options]

Options:
    --json      Output in JSON format
    --env       Output as environment variables
    --validate  Validate detection and show recommendations
    --help      Show this help message

Examples:
    $0                    # Human-readable output
    $0 --json            # JSON output for scripts
    $0 --env             # Environment variables for sourcing
    $0 --validate        # Validate detection with recommendations
EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if $validate_only; then
        validate_hardware
    else
        generate_profile "$output_format"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi