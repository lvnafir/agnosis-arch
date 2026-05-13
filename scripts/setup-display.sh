#!/bin/bash

# Auto-detect DSI panels and configure rotation for hyprland
# Run after bootstrap to patch hyprland.conf for the detected display

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

# detect DSI output
DSI_OUTPUT=$(ls /sys/class/drm/ 2>/dev/null | grep -i "DSI" | head -1 | sed 's/card[0-9]*-//')

if [[ -n "$DSI_OUTPUT" ]]; then
    echo "[INFO] DSI panel detected: $DSI_OUTPUT"

    # check if panel is portrait (height > width in native mode)
    MODES=$(cat /sys/class/drm/card*-${DSI_OUTPUT}/modes 2>/dev/null | head -1)
    if [[ -n "$MODES" ]]; then
        RES_X=$(echo "$MODES" | cut -dx -f1)
        RES_Y=$(echo "$MODES" | cut -dx -f2)

        if [[ "$RES_Y" -gt "$RES_X" ]]; then
            echo "[INFO] Portrait panel detected (${RES_X}x${RES_Y}), applying rotation"

            # determine scale based on resolution
            SCALE="1"
            if [[ "$RES_Y" -ge 1920 ]]; then
                SCALE="1.5"  # high-DPI small panel
            fi

            # patch hyprland.conf
            sed -i '/^monitor=eDP-1/s/^/#/' "$HYPR_CONF"
            sed -i "s|^# monitor=DSI-1.*transform,1$|monitor=${DSI_OUTPUT},preferred,auto,${SCALE},transform,1|" "$HYPR_CONF"

            echo "[OK] Configured $DSI_OUTPUT at scale $SCALE with 90-degree rotation"

            # also add kernel param for TTY rotation
            echo "[INFO] For TTY rotation, add 'fbcon=rotate:1' to kernel cmdline"
        else
            echo "[INFO] Landscape panel, no rotation needed"
        fi
    fi
else
    echo "[INFO] No DSI panel detected, using default monitor config"
fi
