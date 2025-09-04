#!/bin/bash

# --- CONFIGURATION ---
# Path to the CPU temperature sensor file.
# NOTE: Use the correct path for your system.
TEMP_SENSOR="/sys/devices/platform/coretemp.0/hwmon/hwmon8/temp1_input"

# Function to get the current CPU temperature in Celsius
get_cpu_temp() {
    # Read the raw temperature, convert from millidegrees to degrees Celsius
    cat "$TEMP_SENSOR" | awk '{printf "%.0f\n", $1 / 1000}'
}

# --- STRESS TEST FUNCTION ---
run_stress_test_and_log() {
    local load_level="$1"
    local duration="$2"
    local method="matrixprod"

    echo "Running stress-ng at ${load_level}% load for ${duration}s..."
    echo "----------------------------------------"
    echo "Time,Temperature" > "stress_log_${load_level}%.csv"

    start_time=$(date +%s)
    end_time=$((start_time + duration))
    total_temp=0
    temp_count=0

    # Start stress-ng in the background
    stress-ng --cpu 0 --cpu-load "${load_level}" --cpu-method "${method}" --timeout "${duration}s" &
    stress_pid=$!

    # Log temperature and wait for stress-ng to finish
    while [ "$(date +%s)" -le "$end_time" ]; do
        current_temp=$(get_cpu_temp)
        echo "$(date +%s),${current_temp}" >> "stress_log_${load_level}%.csv"
        total_temp=$((total_temp + current_temp))
        temp_count=$((temp_count + 1))
        sleep 1
    done

    # Wait for the stress-ng process to fully terminate
    wait $stress_pid

    # Calculate and print the average temperature
    if [ "$temp_count" -gt 0 ]; then
        avg_temp=$((total_temp / temp_count))
        echo "Average temp for ${load_level}% load: ${avg_temp}°C"
        echo "----------------------------------------"
    else
        echo "Could not collect temperature data."
    fi
}

# --- MAIN SCRIPT EXECUTION ---
echo "Starting scripted stress test with temperature logging."

# Stress Level 1: 25% CPU load for 15 seconds
run_stress_test_and_log 25 15

# Stress Level 2: 50% CPU load for 15 seconds
run_stress_test_and_log 50 15

# Stress Level 3: 75% CPU load for 15 seconds
run_stress_test_and_log 75 15

# Stress Level 4: 100% CPU load for 15 seconds
run_stress_test_and_log 100 15

echo "All stress tests and logging complete."

