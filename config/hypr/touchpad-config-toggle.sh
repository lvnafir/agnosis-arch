#!/bin/bash

# Hyprland Touchpad Config Toggle Script
# Toggles touchpad by editing hyprland.conf device config

CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"
DEVICE_NAME="synps/2-synaptics-touchpad"
LOG_FILE="/tmp/touchpad-toggle.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_touchpad_config() {
    # Check if touchpad device block exists and get its enabled state
    local device_block=$(awk '/device \{/,/^\}/' "$CONFIG_FILE" | grep -A 10 "name = $DEVICE_NAME")

    if [ -n "$device_block" ]; then
        if echo "$device_block" | grep -q "enabled = true"; then
            echo "enabled"
        elif echo "$device_block" | grep -q "enabled = false"; then
            echo "disabled"
        else
            echo "none"
        fi
    else
        echo "none"
    fi
}

add_touchpad_config() {
    local enabled_state="$1"
    log "Adding touchpad device config with enabled = $enabled_state"

    # Add device config at end of file
    cat >> "$CONFIG_FILE" << EOF

# Touchpad device configuration
device {
    name = $DEVICE_NAME
    enabled = $enabled_state
}
EOF
}

update_touchpad_config() {
    local new_state="$1"
    log "Updating touchpad enabled state to $new_state"

    # Use awk to update the enabled line in the touchpad device block
    awk -v device="$DEVICE_NAME" -v state="$new_state" '
    /device \{/ { in_device = 1 }
    in_device && /name = / && $0 ~ device { target_device = 1 }
    target_device && /enabled = / { $0 = "    enabled = " state; target_device = 0 }
    /^\}/ && in_device { in_device = 0; target_device = 0 }
    { print }
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

remove_touchpad_config() {
    log "Removing touchpad device config"

    # Remove the entire device block for touchpad
    sed -i "/# Touchpad device configuration/,/^}$/d" "$CONFIG_FILE"
}

reload_hyprland() {
    hyprctl reload
    if [ $? -eq 0 ]; then
        echo "✓ Hyprland reloaded"
        log "Hyprland successfully reloaded"
    else
        echo "✗ Failed to reload Hyprland"
        log "ERROR: Failed to reload Hyprland"
    fi
}

main() {
    log "Starting touchpad config toggle"

    current_state=$(check_touchpad_config)

    case "$current_state" in
        "enabled")
            echo "Touchpad currently enabled, disabling..."
            update_touchpad_config "false"
            reload_hyprland
            echo "✓ Touchpad disabled"
            log "Touchpad disabled via config update"
            ;;
        "disabled")
            echo "Touchpad currently disabled, enabling..."
            update_touchpad_config "true"
            reload_hyprland
            echo "✓ Touchpad enabled"
            log "Touchpad enabled via config update"
            ;;
        "none")
            echo "No touchpad config found, adding disabled config..."
            add_touchpad_config "false"
            reload_hyprland
            echo "✓ Touchpad disabled"
            log "Touchpad disabled via new config"
            ;;
    esac

    log "Touchpad config toggle completed"
}

case "${1:-}" in
    --status)
        state=$(check_touchpad_config)
        echo "Touchpad config status: $state"
        ;;
    --enable)
        if [ "$(check_touchpad_config)" = "none" ]; then
            add_touchpad_config "true"
        else
            update_touchpad_config "true"
        fi
        reload_hyprland
        echo "✓ Touchpad enabled"
        ;;
    --disable)
        if [ "$(check_touchpad_config)" = "none" ]; then
            add_touchpad_config "false"
        else
            update_touchpad_config "false"
        fi
        reload_hyprland
        echo "✓ Touchpad disabled"
        ;;
    --remove)
        remove_touchpad_config
        reload_hyprland
        echo "✓ Touchpad config removed"
        ;;
    --help)
        echo "Usage: $0 [--status|--enable|--disable|--remove|--help]"
        echo "  --status   Show current touchpad config status"
        echo "  --enable   Enable touchpad in config"
        echo "  --disable  Disable touchpad in config"
        echo "  --remove   Remove touchpad config entirely"
        echo "  --help     Show this help"
        echo "  (no args)  Toggle touchpad state"
        ;;
    *)
        main
        ;;
esac