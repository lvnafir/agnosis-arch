#!/usr/bin/env bash
set -euo pipefail

# WiFi menu - simplified to use fuzzel.ini defaults
# All styling comes from ~/.config/fuzzel/fuzzel.ini

# Generic fuzzel wrapper functions - only position and size parameters needed
show_menu() {
    local prompt="$1" width="$2" lines="$3" anchor="${4:-top-right}" x_margin="${5:-0}" y_margin="${6:-0}"
    shift 6
    printf '%s\n' "$@" | fuzzel --dmenu --prompt "$prompt" --width "$width" --lines "$lines" --anchor "$anchor" --x-margin "$x_margin" --y-margin "$y_margin"
}

show_input() {
    local prompt="$1" width="${2:-30}" anchor="${3:-center}" password="${4:-}"
    local pwd_flag=""
    [ -n "$password" ] && pwd_flag="--password"
    echo "" | fuzzel --dmenu $pwd_flag --prompt "$prompt" --width "$width" --lines 0 --anchor "$anchor"
}

notify() {
    local message="$1" icon="${2:-network-wireless}" urgency="${3:-normal}"
    local urgency_flag=""
    [ "$urgency" = "critical" ] && urgency_flag="-u critical"
    notify-send $urgency_flag "WiFi" "$message" -i "$icon"
}

# Function to get signal strength icon
get_signal_icon() {
    local strength=$1
    # Handle non-numeric values (like "****" for hidden networks)
    if [[ ! "$strength" =~ ^-?[0-9]+$ ]]; then
        echo "󰤢"  # Default to fair signal
        return
    fi
    
    if [ "$strength" -ge -30 ]; then
        echo "󰤨"  # Excellent
    elif [ "$strength" -ge -50 ]; then
        echo "󰤥"  # Good
    elif [ "$strength" -ge -60 ]; then
        echo "󰤢"  # Fair
    elif [ "$strength" -ge -70 ]; then
        echo "󰤟"  # Weak
    else
        echo "󰤯"  # Very weak
    fi
}

# Function to get security icon
get_security_icon() {
    local security=$1
    if [[ "$security" == "open" ]]; then
        echo "󰦞"  # Open network
    else
        echo "󰦝"  # Secured network
    fi
}

# Function to show password dialog
get_password() {
    local network_name="$1" retry_message="${2:-}"
    local prompt="$network_name:"
    [ -n "$retry_message" ] && prompt="$retry_message"$'\n'"$network_name:"
    show_input "$prompt" 30 center password
}

# Function to connect to network
connect_to_network() {
    local device="$1"
    local network="$2"
    local password="$3"
    
    if [ -z "$password" ]; then
        # Try connecting without password (open network or saved)
        timeout 10s iwctl station "$device" connect "$network" &>/dev/null
    else
        # Connect with password using corrected iwctl syntax
        timeout 10s iwctl --passphrase "$password" station "$device" connect "$network" &>/dev/null
    fi
}

# Function to verify connection
verify_connection() {
    local device="$1"
    local network="$2"
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local current_network=$(iwctl station "$device" show 2>/dev/null | grep "Connected network" | awk '{print $3}' || echo "")
        
        if [ "$current_network" = "$network" ]; then
            return 0  # Connected successfully
        fi
        
        sleep 1
        ((attempt++))
    done
    
    return 1  # Connection failed
}

# Function to attempt connection with notifications
attempt_connection() {
    local device="$1"
    local network="$2"
    local password="${3:-}"
    
    notify "Connecting to $network..."
    
    if connect_to_network "$device" "$network" "$password" && verify_connection "$device" "$network"; then
        notify "Successfully connected to $network" "network-wireless-connected"
        return 0
    else
        notify "Failed to connect to $network" "network-wireless-offline" "critical"
        return 1
    fi
}

# Function to show confirmation dialog
confirm_forget() {
    show_input "Forget '$1'? (yes/no):" 35
}

# Function to show network action menu
show_network_actions() {
    local device="$1"
    local network="$2"
    local current_network="$3"
    
    local actions=()
    local is_connected=false
    local is_known=false
    
    # Check if currently connected
    if [ "$network" = "$current_network" ]; then
        is_connected=true
    fi
    
    # Check if network is known
    if iwctl known-networks list | grep -q "^  $network "; then
        is_known=true
    fi
    
    # Build action menu based on network status
    if [ "$is_connected" = true ]; then
        actions+=("󰅖  Disconnect")
        actions+=("󰩹  Forget Network")
    elif [ "$is_known" = true ]; then
        actions+=("󰁅  Connect")
        actions+=("󰩹  Forget Network")
    else
        actions+=("󰁅  Connect")
    fi
    
    # Show action menu
    show_menu "Actions for '$network':" 35 ${#actions[@]} top-right $X_MARGIN 0 "${actions[@]}"
}

# Main script starts here
# Get the wireless device name
DEVICE=$(iwctl device list | grep -E "wlan|wlp" | awk '{print $2}' | head -1)

if [ -z "$DEVICE" ]; then
    notify "No wireless device found" "network-wireless" "critical"
    exit 1
fi

# Get current connected network
CURRENT_NETWORK=$(iwctl station "$DEVICE" show 2>/dev/null | grep "Connected network" | awk '{print $3}' || echo "")


# Scan for networks
notify-send -t 500 "WiFi" "Scanning for networks..." -i "network-wireless"
iwctl station "$DEVICE" scan &>/dev/null
sleep 0.25

# Build the menu options
OPTIONS=()

# Add control options first
OPTIONS+=("󰖪  Disconnect")
OPTIONS+=("󰑓  Rescan Networks")
OPTIONS+=("──────────────────────────────────")  # Separator

# Parse available networks (strip ANSI color codes)
NETWORKS=$(iwctl station "$DEVICE" get-networks | sed 's/\x1b\[[0-9;]*m//g' | tail -n +5 | head -n -1)

while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Check if this is the connected network
    if [[ "$line" =~ ^[[:space:]]*\> ]]; then
        line=$(echo "$line" | sed 's/^[[:space:]]*>//;s/^[[:space:]]*//')
        is_connected=true
    else
        is_connected=false
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    # Extract network name, security, and signal
    network_name=$(echo "$line" | awk '{for(i=1;i<NF-1;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    security=$(echo "$line" | awk '{print $(NF-1)}')
    signal=$(echo "$line" | awk '{print $NF}')
    
    # Skip if we couldn't parse properly
    [ -z "$network_name" ] && continue
    
    # Get icons
    signal_icon=$(get_signal_icon "$signal")
    security_icon=$(get_security_icon "$security")
    
    # Format the menu entry
    if [ "$is_connected" = true ]; then
        OPTIONS+=("$signal_icon $security_icon  $network_name [Connected]")
    else
        OPTIONS+=("$signal_icon $security_icon  $network_name")
    fi
done <<< "$NETWORKS"

# Calculate approximate position of network module
# Network module is in modules-right: backlight, pulseaudio, easyeffects, network, wifi-test, battery, clock
# Estimate: each module ~60px wide, network is 3rd from right
# So roughly: clock(60) + battery(60) + network(60) = 180px from right edge
SCREEN_WIDTH=$(hyprctl monitors | grep -A 10 "eDP-1" | grep -o "[0-9]*x[0-9]*" | cut -d'x' -f1)
MENU_WIDTH=320  # Width of our menu in pixels (35 chars * ~9px per char)
NETWORK_MODULE_OFFSET=180  # Estimated distance from right edge
X_MARGIN=$((NETWORK_MODULE_OFFSET - MENU_WIDTH / 2))

# Show the dropdown menu positioned under network module
CHOICE=$(show_menu "WiFi Networks:" 35 12 top-right $X_MARGIN 0 "${OPTIONS[@]}")

# Handle the choice
case "$CHOICE" in
    *Disconnect*)
        iwctl station "$DEVICE" disconnect
        notify "Disconnected from network" "network-wireless-offline"
        ;;
    *Rescan*)
        # Just reopen the menu (scanning happens automatically on menu open)
        exec "$0"
        ;;
    "──────────────────────────────────"|"")
        # Separator or cancelled - do nothing
        exit 0
        ;;
    *)
        # Extract network name from the choice
        NETWORK=$(echo "$CHOICE" | sed 's/^[^ ]* [^ ]*  //;s/ \[Connected\]$//')
        
        # Show action menu for the selected network
        while true; do
            ACTION=$(show_network_actions "$DEVICE" "$NETWORK" "$CURRENT_NETWORK")
            
            case "$ACTION" in
                *Disconnect*)
                    iwctl station "$DEVICE" disconnect
                    notify "Disconnected from $NETWORK" "network-wireless-offline"
                    break
                    ;;
                *"Forget Network"*)
                    CONFIRM=$(confirm_forget "$NETWORK")
                    if [[ "$CONFIRM" =~ ^[Yy]([Ee][Ss])?$ ]]; then
                        iwctl known-networks "$NETWORK" forget
                        notify "Forgot network $NETWORK" "network-wireless"
                        break
                    elif [[ "$CONFIRM" =~ ^[Nn]([Oo])?$ ]]; then
                        # User said no, re-run main menu
                        exec "$0"
                    else
                        # Invalid response, show action menu again
                        continue
                    fi
                    ;;
                *Connect*)
                    # Check if network is already known (saved)
                    if iwctl known-networks list | grep -q "^  $NETWORK "; then
                        # Known network - connect directly
                        attempt_connection "$DEVICE" "$NETWORK"
                        break
                    elif [[ "$CHOICE" == *"󰦞"* ]]; then
                        # Open network - connect directly
                        attempt_connection "$DEVICE" "$NETWORK"
                        break
                    else
                        # Secured network - need password
                        MAX_RETRIES=3
                        RETRY_COUNT=0
                        RETRY_MESSAGE=""
                        
                        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                            PASSWORD=$(get_password "$NETWORK" "$RETRY_MESSAGE")
                            
                            # Check if user cancelled password dialog
                            if [ -z "$PASSWORD" ]; then
                                notify "Connection cancelled"
                                break 2
                            fi
                            
                            if attempt_connection "$DEVICE" "$NETWORK" "$PASSWORD"; then
                                break 2
                            else
                                ((RETRY_COUNT++))
                                if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                                    RETRY_MESSAGE="❌ Connection failed. Try again:"
                                else
                                    notify "Failed to connect to $NETWORK after $MAX_RETRIES attempts" "network-wireless-offline" "critical"
                                    break 2
                                fi
                            fi
                        done
                    fi
                    ;;
                "")
                    # User cancelled action menu
                    break
                    ;;
            esac
        done
        ;;
esac