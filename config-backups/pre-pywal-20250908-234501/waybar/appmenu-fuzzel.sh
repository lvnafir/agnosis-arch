#!/usr/bin/env bash
set -euo pipefail

# ================================
# App Menu with Fuzzel
# ================================

# Configuration
SCRIPT_NAME="appmenu-fuzzel"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SCRIPT_NAME"
DESKTOP_DIRS=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/applications"
)

# Terminal to use for terminal apps
TERMINAL="kitty"

# Fuzzel configuration with search bar
FUZZEL_WIDTH=40
FUZZEL_HEIGHT=15
FUZZEL_FONT="Caskaydia Cove Nerd Font:size=8"
FUZZEL_BG="1e1e2eff"     # Catppuccin background
FUZZEL_FG="cdd6f4ff"     # Catppuccin text
FUZZEL_SEL_BG="cba6f7ff" # Catppuccin mauve selection
FUZZEL_SEL_FG="1e1e2eff" # Dark text on selection
FUZZEL_MATCH="f38ba8ff"  # Catppuccin red for matches
FUZZEL_PROMPT="cba6f7ff" # Catppuccin mauve for prompt
FUZZEL_BORDER="313244ff" # Catppuccin surface0 border

# Create cache directory if needed
mkdir -p "$CACHE_DIR"

# Generic fuzzel wrapper function with search prompt
fuzzel_menu() {
    local prompt="$1"
    shift
    fuzzel \
        --prompt="$prompt " \
        --width="$FUZZEL_WIDTH" \
        --lines="$FUZZEL_HEIGHT" \
        --font="$FUZZEL_FONT" \
        --background-color="$FUZZEL_BG" \
        --text-color="$FUZZEL_FG" \
        --selection-color="$FUZZEL_SEL_BG" \
        --selection-text-color="$FUZZEL_SEL_FG" \
        --match-color="$FUZZEL_MATCH" \
        --prompt-color="$FUZZEL_PROMPT" \
        --border-width=2 \
        --border-color="$FUZZEL_BORDER" \
        --border-radius=12 \
        --inner-pad=0 \
        --horizontal-pad=15 \
        --vertical-pad=8 \
        --layer=overlay \
        "$@"
}

# Parse .desktop file for app info
parse_desktop_file() {
    local file="$1"
    local name=""
    local exec=""
    local terminal="false"
    local nodisplay="false"
    
    while IFS= read -r line; do
        case "$line" in
            Name=*)
                [[ -z "$name" ]] && name="${line#Name=}"
                ;;
            Exec=*)
                exec="${line#Exec=}"
                # Remove field codes (%f, %F, %u, %U, etc.)
                exec="${exec//%[fFuUdDnNickvm]/}"
                ;;
            Terminal=true)
                terminal="true"
                ;;
            NoDisplay=true)
                nodisplay="true"
                ;;
        esac
    done < "$file"
    
    # Skip if NoDisplay is set or no name/exec
    [[ "$nodisplay" == "true" || -z "$name" || -z "$exec" ]] && return
    
    # Output format: Name|Exec|Terminal
    echo "${name}|${exec}|${terminal}"
}

# Build app list from .desktop files
build_app_list() {
    local cache_file="$CACHE_DIR/apps.cache"
    local temp_file="$CACHE_DIR/apps.temp"
    
    # Check if cache is fresh (less than 5 minutes old)
    if [[ -f "$cache_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0))) -lt 300 ]]; then
        cat "$cache_file"
        return
    fi
    
    # Build fresh app list
    > "$temp_file"
    
    for dir in "${DESKTOP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        
        for desktop_file in "$dir"/*.desktop; do
            [[ -f "$desktop_file" ]] || continue
            parse_desktop_file "$desktop_file" >> "$temp_file"
        done
    done
    
    # Sort and remove duplicates by app name
    sort -t'|' -k1,1 -u "$temp_file" > "$cache_file"
    cat "$cache_file"
}

# Launch selected application
launch_app() {
    local selection="$1"
    local app_info
    
    # Find the app info from our list
    app_info=$(build_app_list | grep "^${selection}|" | head -1)
    
    if [[ -n "$app_info" ]]; then
        local name exec terminal
        IFS='|' read -r name exec terminal <<< "$app_info"
        
        # Clean up the exec command
        exec=$(echo "$exec" | xargs)
        
        # Launch the application
        if [[ "$terminal" == "true" ]]; then
            # Terminal application
            $TERMINAL -e $exec &
        else
            # GUI application
            $exec &
        fi
        
        # Small delay to ensure app starts
        sleep 0.2
    fi
}

# Main menu function
show_app_menu() {
    # Build the app list and extract just names for display
    local apps
    apps=$(build_app_list | cut -d'|' -f1)
    
    # Show fuzzel menu with search prompt
    local selection
    selection=$(echo "$apps" | fuzzel_menu "󰍉 Search Apps")
    
    # Launch the selected app if any
    if [[ -n "$selection" ]]; then
        launch_app "$selection"
    fi
}

# Kill any existing fuzzel instances for this menu
pkill -f "fuzzel.*Search Apps" 2>/dev/null || true

# Show the app menu
show_app_menu