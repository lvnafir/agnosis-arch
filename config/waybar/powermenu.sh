#!/usr/bin/env bash
set -euo pipefail

# Create a temporary CSS file for this specific menu
TEMP_CSS=$(mktemp --suffix=.css)
trap 'rm -f "$TEMP_CSS"' EXIT

# Write inline CSS to match Waybar styling
cat > "$TEMP_CSS" << 'EOF'
window {
    font-family: "Caskaydia Cove Nerd Font", monospace;
    background-color: #1e1e2e;
    border-radius: 8px;
    border: 2px solid #313244;
}

#input {
    padding: 0;
    margin: 0;
    border: none;
    min-height: 0;
    opacity: 0;
    height: 0;
}

#inner-box {
    margin: 0px;
    border-radius: 8px;
    padding: 0;
}

#outer-box {
    margin: 0px;
    border-radius: 8px;
    padding: 0;
}

#scroll {
    margin: 0;
    padding: 0;
}

#text {
    margin: 5px;
    padding: 8px;
    color: #cdd6f4;
}

#entry {
    padding: 8px;
    margin: 2px;
    border-radius: 8px;
    background-color: transparent;
    transition: all 0.2s ease;
}

/* Shutdown - Red */
#entry:nth-child(1):selected {
    background-color: #f38ba8;
}

/* Reboot - Yellow */
#entry:nth-child(2):selected {
    background-color: #f9e2af;
}

/* Logout - Green */
#entry:nth-child(3):selected {
    background-color: #a6e3a1;
}

/* Lock - Blue */
#entry:nth-child(4):selected {
    background-color: #89b4fa;
}

/* Suspend - Purple */
#entry:nth-child(5):selected {
    background-color: #cba6f7;
}

/* Selected text color */
#entry:selected {
    margin-left: 5px;
}

#entry:selected #text {
    color: #1e1e2e;
    font-weight: bold;
}
EOF

# Options with icons - using better nerd font icons
options=("󰐥  Shutdown" "󰜉  Reboot" "󰍃  Logout" "󰌾  Lock" "󰤄  Suspend")

# Use wofi with hidden search input
choice=$(printf '%s\n' "${options[@]}" | wofi --dmenu --insensitive --width 250 \
  --location 1 --yoffset -45 --xoffset 10 \
  --style "$TEMP_CSS" --hide-search=true \
  --prompt="" --search="" \
  --cache-file /dev/null \
  --no-actions \
  --lines 5)

# Temporary file cleaned up by trap on EXIT

# Execute based on choice
case "$choice" in
    *Shutdown)
        systemctl poweroff
        ;;
    *Reboot)
        systemctl reboot
        ;;
    *Logout)
        if command -v uwsm >/dev/null 2>&1; then
            uwsm stop
        else
            hyprctl dispatch exit
        fi
        ;;
    *Lock)
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
