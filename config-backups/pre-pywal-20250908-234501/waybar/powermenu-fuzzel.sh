#!/usr/bin/env bash
set -euo pipefail

# Power menu using fuzzel - simplified to use fuzzel.ini defaults
# All styling comes from ~/.config/fuzzel/fuzzel.ini

# Power menu function - only position and size parameters needed
show_power_menu() {
    local prompt="$1" width="$2" lines="$3" anchor="${4:-top-left}" x_margin="${5:-0}" y_margin="${6:-0}"
    shift 6
    printf '%s\n' "$@" | fuzzel --dmenu --prompt "$prompt" --width "$width" --lines "$lines" --anchor "$anchor" --x-margin "$x_margin" --y-margin "$y_margin" --hide-prompt
}

# Input dialogue function - simplified
show_input() {
    local prompt="$1" width="${2:-30}" anchor="${3:-center}"
    echo "" | fuzzel --dmenu --prompt "$prompt" --width "$width" --lines 0 --anchor "$anchor"
}

# Confirmation function
confirm_action() {
    local action="$1"
    local response
    response=$(show_input "$action? (y/n): " 25 "center")
    
    case "${response,,}" in  # Convert to lowercase
        y|yes|"$action")
            return 0  # Confirmed
            ;;
        n|no|"")
            return 1  # Cancelled
            ;;
        *)
            return 1  # Default to cancel for any other input
            ;;
    esac
}

# Options with icons
options=("󰐥  Shutdown" "󰜉  Reboot" "󰍃  Logout" "󰌾  Lock" "󰤄  Suspend")

# Show power menu using consistent design
choice=$(show_power_menu "" 18 5 "top-left" 0 0 "${options[@]}")

# Execute based on choice
case "$choice" in
    *Shutdown)
        if confirm_action "shutdown"; then
            systemctl poweroff
        fi
        ;;
    *Reboot)
        if confirm_action "reboot"; then
            systemctl reboot
        fi
        ;;
    *Logout)
        if confirm_action "logout"; then
            if command -v uwsm >/dev/null 2>&1; then
                uwsm stop
            else
                hyprctl dispatch exit
            fi
        fi
        ;;
    *Lock)
        # Lock doesn't need confirmation - it's not destructive
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock
        elif [ -x /sbin/hyprlock ]; then
            /sbin/hyprlock
        else
            echo "Error: hyprlock not found" >&2
            exit 1
        fi
        ;;
    *Suspend)
        # Suspend doesn't need confirmation - it's not destructive
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock &
        elif [ -x /sbin/hyprlock ]; then
            /sbin/hyprlock &
        fi
        sleep 1 && systemctl suspend
        ;;
    *)
        # No selection or cancelled
        ;;
esac