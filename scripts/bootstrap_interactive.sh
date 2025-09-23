#!/bin/bash

set -e

# Interactive Bootstrap Orchestrator for Agnosis Arch
# Combines testbed modularity with original interactivity
# Addresses all FAAR analysis security and logic issues

REPO_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
SCRIPTS_DIR="$REPO_DIR/scripts"

# Colors for output
if [ -t 1 ] && command -v tput &> /dev/null && tput colors &> /dev/null && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

print_header() {
    echo ""
    echo "================================================================================="
    echo -e "${BLUE}$1${NC}"
    echo "================================================================================="
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        echo -n "$prompt (y/n): "
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

run_phase() {
    local phase_num="$1"
    local phase_script=""

    # Find the phase script
    case "$phase_num" in
        1) phase_script="phase_1_environment.py" ;;
        2) phase_script="phase_2_hardware.py" ;;
        3) phase_script="phase_3_packages.py" ;;
        4) phase_script="phase_4_config.py" ;;
        5) phase_script="phase_5_theme.py" ;;
        6) phase_script="phase_6_services.py" ;;
        7) phase_script="phase_7_validation.py" ;;
        8) phase_script="phase_8_launch.py" ;;
        *)
            print_error "Unknown phase: $phase_num"
            return 1
            ;;
    esac

    local script_path="$SCRIPTS_DIR/$phase_script"

    if [[ ! -f "$script_path" ]]; then
        print_error "Phase script not found: $script_path"
        return 1
    fi

    print_info "Executing Phase $phase_num..."

    # Execute the phase script
    if python3 "$script_path"; then
        print_success "Phase $phase_num completed successfully"
        return 0
    else
        print_error "Phase $phase_num failed"
        return 1
    fi
}

handle_phase_failure() {
    local phase_num="$1"

    print_error "Bootstrap failed at Phase $phase_num"
    echo ""
    print_info "You can:"
    print_info "1. Fix the issue and re-run bootstrap (completed phases will be skipped)"
    print_info "2. Run individual phases manually with: python3 scripts/phase_N_name.py"
    print_info "3. Check logs for detailed error information"
    echo ""
}

show_manual_setup_guide() {
    print_header "Manual Setup Guide"
    print_info "You chose not to run the automated bootstrap. Here are your options:"
    echo ""
    print_info "Run individual phases:"
    print_info "  Phase 1: python3 scripts/phase_1_environment.py"
    print_info "  Phase 2: python3 scripts/phase_2_hardware.py"
    print_info "  Phase 3: python3 scripts/phase_3_packages.py"
    print_info "  Phase 4: python3 scripts/phase_4_config.py"
    print_info "  Phase 5: python3 scripts/phase_5_theme.py"
    print_info "  Phase 6: python3 scripts/phase_6_services.py"
    print_info "  Phase 7: python3 scripts/phase_7_validation.py"
    print_info "  Phase 8: python3 scripts/phase_8_launch.py"
    echo ""
    print_info "Or re-run this script when ready: ./scripts/bootstrap_interactive.sh"
}

validate_environment() {
    print_header "Pre-flight Validation"

    # Check if we're on Arch Linux
    if [[ ! -f /etc/arch-release ]]; then
        print_error "This script requires Arch Linux"
        return 1
    fi

    # Check if we're in the right directory
    if [[ ! -d "$REPO_DIR/scripts" ]] || [[ ! -d "$REPO_DIR/config" ]]; then
        print_error "Please run this script from the agnosis-arch repository root"
        print_info "Current directory: $(pwd)"
        print_info "Expected: agnosis-arch repository with scripts/ and config/ directories"
        return 1
    fi

    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        print_info "Install with: sudo pacman -S python"
        return 1
    fi

    # Validate all phase scripts exist and make them executable
    local phase_scripts=(
        "phase_1_environment.py"
        "phase_2_hardware.py"
        "phase_3_packages.py"
        "phase_4_config.py"
        "phase_5_theme.py"
        "phase_6_services.py"
        "phase_7_validation.py"
        "phase_8_launch.py"
    )

    for script in "${phase_scripts[@]}"; do
        local script_path="$SCRIPTS_DIR/$script"
        if [[ ! -f "$script_path" ]]; then
            print_error "Missing phase script: $script"
            return 1
        fi
        # Make executable
        chmod +x "$script_path"
    done

    print_success "Pre-flight validation passed"
    return 0
}

main() {
    print_header "Agnosis Arch Interactive Bootstrap System"
    print_info "This will install and configure a complete Hyprland desktop environment"
    echo ""

    # Pre-flight validation
    if ! validate_environment; then
        exit 1
    fi

    # Main confirmation
    print_info "This bootstrap will:"
    print_info "  • Detect your hardware and install appropriate packages"
    print_info "  • Configure Hyprland, Waybar, and desktop applications"
    print_info "  • Set up theme system with pywal"
    print_info "  • Configure system services"
    print_info "  • Launch the desktop environment"
    echo ""

    if ask_yes_no "Do you want to begin the interactive bootstrap process?"; then
        print_success "Starting bootstrap process..."
        echo ""

        # Execute all phases
        for phase in {1..8}; do
            if ! run_phase "$phase"; then
                handle_phase_failure "$phase"
                exit 1
            fi
            echo ""
        done

        print_header "Bootstrap Completed Successfully!"
        print_success "Your Agnosis Arch system is now configured and ready to use"
        print_info "The desktop environment should be launching automatically"

    else
        show_manual_setup_guide
    fi
}

# Run main function
main "$@"