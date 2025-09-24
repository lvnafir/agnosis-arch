#!/bin/bash

# Pywal hook script - runs after color generation
# This script is called automatically by pywal when colors are generated
# Usage: Called by pywal with -o flag: wal -i wallpaper.jpg -o ~/.config/wal/done.sh

set -euo pipefail

echo "[PYWAL-HOOK] Running pywal hooks..."

# Path to hook scripts (installed by bootstrap to ~/.local/bin)
HOOK_DIR="$HOME/.local/bin"

# Array of hook scripts to run in order
# These correspond to the pywal-integration scripts in the repo
HOOKS=(
    "fuzzel-pywal-update"
    "hyprland-pywal-update"
    "mako-pywal-update"
    "waybar-pywal-update"
)

# Track success/failure
successful_hooks=()
failed_hooks=()

# Run each hook if it exists and is executable
for hook in "${HOOKS[@]}"; do
    hook_path="$HOOK_DIR/$hook"
    if [[ -x "$hook_path" ]]; then
        echo "[PYWAL-HOOK] Running $hook..."
        if "$hook_path" 2>/dev/null; then
            successful_hooks+=("$hook")
            echo "[PYWAL-HOOK] ✓ $hook completed successfully"
        else
            failed_hooks+=("$hook")
            echo "[PYWAL-HOOK] ✗ $hook failed"
        fi
    else
        echo "[PYWAL-HOOK] Warning: $hook not found or not executable at $hook_path"
        failed_hooks+=("$hook (not found)")
    fi
done

# Summary
echo "[PYWAL-HOOK] Hook execution summary:"
if [[ ${#successful_hooks[@]} -gt 0 ]]; then
    echo "[PYWAL-HOOK] Successful: ${successful_hooks[*]}"
fi
if [[ ${#failed_hooks[@]} -gt 0 ]]; then
    echo "[PYWAL-HOOK] Failed: ${failed_hooks[*]}"
fi

echo "[PYWAL-HOOK] Pywal color scheme update complete"