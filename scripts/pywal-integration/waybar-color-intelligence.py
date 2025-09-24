#!/usr/bin/env python3
"""
Waybar Color Intelligence Script
Analyzes pywal colors and intelligently assigns accent/complement colors to waybar modules
Updates the existing style.css without regenerating it completely
"""

import json
import re
import colorsys
from pathlib import Path

def load_pywal_colors():
    """Load colors from pywal's colors.json"""
    colors_file = Path.home() / ".cache" / "wal" / "colors.json"
    if not colors_file.exists():
        raise FileNotFoundError("Pywal colors.json not found. Run pywal first.")

    with open(colors_file, 'r') as f:
        data = json.load(f)

    # Combine colors and special colors into one dict
    all_colors = data['colors'].copy()
    all_colors.update(data['special'])
    return all_colors

def hex_to_hsl(hex_color):
    """Convert hex color to HSL"""
    hex_color = hex_color.lstrip('#')
    r, g, b = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    r, g, b = r/255.0, g/255.0, b/255.0
    return colorsys.rgb_to_hls(r, g, b)

def find_most_vibrant_color(colors):
    """Find the most vibrant/saturated color from pywal palette and return the color variable name"""
    max_saturation = 0
    most_vibrant_key = 'color1'  # fallback
    most_vibrant_hex = colors['color1']

    # Check colors 1-15 (skip 0,7 which are usually bg/fg variants)
    for i in range(1, 16):
        if i == 7:  # Skip color7 (usually white/light foreground)
            continue
        color_key = f'color{i}'
        if color_key in colors:
            h, l, s = hex_to_hsl(colors[color_key])
            # Heavily prioritize pure saturation for maximum vibrance
            vibrancy_score = s * s * (1 - abs(l - 0.45))  # Square saturation for emphasis
            if vibrancy_score > max_saturation:
                max_saturation = vibrancy_score
                most_vibrant_key = color_key
                most_vibrant_hex = colors[color_key]

    return most_vibrant_key, most_vibrant_hex

def find_best_complement_color(colors, accent_color_key):
    """Find the best complementary color from existing pywal palette"""
    accent_hex = colors[accent_color_key]
    accent_h, accent_l, accent_s = hex_to_hsl(accent_hex)

    best_complement_key = 'color2'  # fallback
    best_complement_score = -1

    # Check all colors except accent and bg/fg variants
    for i in range(1, 16):
        if i == 0 or i == 7:  # Skip bg/fg variants
            continue
        color_key = f'color{i}'
        if color_key == accent_color_key or color_key not in colors:
            continue

        h, l, s = hex_to_hsl(colors[color_key])

        # Calculate how complementary this color is (should be ~0.5 hue difference for true complement)
        hue_diff = abs(h - accent_h)
        if hue_diff > 0.5:
            hue_diff = 1.0 - hue_diff  # Wrap around color wheel

        # True complementary colors are ~0.5 apart on hue wheel
        complement_distance = abs(hue_diff - 0.5)  # How close to perfect complement (0.5)

        # Score based on: true complementarity (close to 0.5 hue diff), saturation, and lightness balance
        complement_score = (1 - complement_distance * 2) * s * (1 - abs(l - 0.4))

        if complement_score > best_complement_score:
            best_complement_score = complement_score
            best_complement_key = color_key

    return best_complement_key

def calculate_contrast_ratio(color1_hex, color2_hex):
    """Calculate WCAG contrast ratio between two hex colors"""
    def get_luminance(hex_color):
        r = int(hex_color[1:3], 16) / 255.0
        g = int(hex_color[3:5], 16) / 255.0
        b = int(hex_color[5:7], 16) / 255.0

        def gamma_correct(c):
            return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

        return 0.2126 * gamma_correct(r) + 0.7152 * gamma_correct(g) + 0.0722 * gamma_correct(b)

    lum1 = get_luminance(color1_hex)
    lum2 = get_luminance(color2_hex)
    lighter = max(lum1, lum2)
    darker = min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)

def get_best_contrast_text_color(bg_color_hex, colors):
    """Get text color with best contrast ratio for given background"""
    fg_hex = colors['foreground']
    bg_hex = colors['background']

    fg_contrast = calculate_contrast_ratio(fg_hex, bg_color_hex)
    bg_contrast = calculate_contrast_ratio(bg_hex, bg_color_hex)

    return '@foreground' if fg_contrast > bg_contrast else '@background'

def update_waybar_css():
    """Update waybar CSS with intelligent color assignments"""
    colors = load_pywal_colors()

    # Find accent color (most vibrant) - returns semantic variable name
    accent_color_key, accent_hex = find_most_vibrant_color(colors)

    # Find best complement color from existing palette
    complement_color_key = find_best_complement_color(colors, accent_color_key)
    complement_hex = colors[complement_color_key]

    # Text colors will be calculated per module for optimal contrast

    print(f"[WAYBAR-INTELLIGENCE] Accent color: @{accent_color_key} ({accent_hex})")
    print(f"[WAYBAR-INTELLIGENCE] Complement color: @{complement_color_key} ({complement_hex})")

    # Define module groups
    accent_modules = [
        'network', 'custom-terminal', 'custom-browser', 'custom-claude',
        'custom-bluetooth', 'custom-power'
    ]

    # Note: workspaces are handled separately in the CSS
    complement_modules = [
        'battery', 'clock', 'memory', 'cpu', 'temperature', 'pulseaudio',
        'backlight', 'custom-appmenu', 'custom-btop', 'cava'
    ]

    # Read current CSS
    css_file = Path.home() / ".config" / "waybar" / "style.css"
    if not css_file.exists():
        raise FileNotError("Waybar style.css not found")

    with open(css_file, 'r') as f:
        css_content = f.read()

    # Update accent modules hover colors with per-module contrast
    for module in accent_modules:
        text_color = get_best_contrast_text_color(accent_hex, colors)
        pattern = f'#{module}:hover\\s*{{[^}}]*}}'
        replacement = f'#{module}:hover {{\n  background: @{accent_color_key};\n  color: {text_color};\n}}'
        css_content = re.sub(pattern, replacement, css_content, flags=re.MULTILINE | re.DOTALL)

    # Update complement modules hover colors with per-module contrast
    for module in complement_modules:
        if module == 'backlight':
            # Special case: backlight uses @foreground background
            text_color = get_best_contrast_text_color(colors['foreground'], colors)
            pattern = f'#{module}:hover\\s*{{[^}}]*}}'
            replacement = f'#{module}:hover {{\n  background: @foreground;\n  color: {text_color};\n}}'
        else:
            text_color = get_best_contrast_text_color(complement_hex, colors)
            pattern = f'#{module}:hover\\s*{{[^}}]*}}'
            replacement = f'#{module}:hover {{\n  background: @{complement_color_key};\n  color: {text_color};\n}}'
        css_content = re.sub(pattern, replacement, css_content, flags=re.MULTILINE | re.DOTALL)

    # Special case: workspaces button hover should use accent
    workspace_text_color = get_best_contrast_text_color(accent_hex, colors)
    pattern = r'#waybar #workspaces button:hover\s*{[^}]*}'
    replacement = f'#waybar #workspaces button:hover {{\n  background: @{accent_color_key};\n  color: {workspace_text_color};\n}}'
    css_content = re.sub(pattern, replacement, css_content, flags=re.MULTILINE | re.DOTALL)

    # Special case: active workspace should use accent color
    pattern = r'#waybar #workspaces button\.active\s*{[^}]*}'
    replacement = f'#waybar #workspaces button.active {{\n  background: @{accent_color_key};\n  color: {workspace_text_color};\n  font-weight: bold;\n}}'
    css_content = re.sub(pattern, replacement, css_content, flags=re.MULTILINE | re.DOTALL)

    # Write updated CSS
    with open(css_file, 'w') as f:
        f.write(css_content)

    print(f"[WAYBAR-INTELLIGENCE] Successfully updated waybar CSS with intelligent colors")
    return True

if __name__ == "__main__":
    try:
        update_waybar_css()
    except Exception as e:
        print(f"[WAYBAR-INTELLIGENCE] ERROR: {e}")
        exit(1)