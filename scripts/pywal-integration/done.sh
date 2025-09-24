#!/bin/bash

# Fast pywal hook script - minimal output for speed
set -euo pipefail

# Hook directory and scripts
HOOK_DIR="$HOME/.local/bin"
HOOKS=("fuzzel-pywal-update" "hyprland-pywal-update" "mako-pywal-update" "waybar-pywal-update")

# Run hooks in parallel for maximum speed
for hook in "${HOOKS[@]}"; do
    hook_path="$HOOK_DIR/$hook"
    if [[ -x "$hook_path" ]]; then
        "$hook_path" >/dev/null 2>&1 &
    fi
done

# Wait for all hooks to complete
wait