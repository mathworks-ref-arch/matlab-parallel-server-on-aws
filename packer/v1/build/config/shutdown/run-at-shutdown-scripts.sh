#!/bin/bash

# Copyright 2024-2025 The MathWorks, Inc.
# Master script that executes all scripts under SHUTDOWN_DIR during system shutdown
set -eoux

# Directory containing shutdown scripts
SHUTDOWN_DIR="/opt/mathworks/shutdown"

# Check if the directory exists
if [ ! -d "$SHUTDOWN_DIR" ]; then
    echo "Shutdown scripts directory not found: $SHUTDOWN_DIR"
    exit 1
fi

# Run all executable scripts in the directory
for script in "$SHUTDOWN_DIR"/*; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Running shutdown script: $script"
        "$script"
    fi
done

echo "All shutdown scripts have been executed."
