#!/bin/bash

echo "Starting custom stress test..."

# Stress Level 1: 25% CPU load for 15 seconds
echo "Stress Level 1 (25%)"
stress-ng --cpu 0 --cpu-load 25 --cpu-method matrixprod --timeout 15s

# Stress Level 2: 50% CPU load for 15 seconds
echo "Stress Level 2 (50%)"
stress-ng --cpu 0 --cpu-load 50 --cpu-method matrixprod --timeout 15s

# Stress Level 3: 75% CPU load for 15 seconds
echo "Stress Level 3 (75%)"
stress-ng --cpu 0 --cpu-load 75 --cpu-method matrixprod --timeout 15s

# Stress Level 4: 100% CPU load for 15 seconds
echo "Stress Level 4 (100%)"
stress-ng --cpu 0 --cpu-load 100 --cpu-method matrixprod --timeout 15s

echo "Custom stress test complete."

