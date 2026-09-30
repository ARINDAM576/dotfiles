#!/bin/bash

# Ensure TARGET_CLASS matches exactly what 'hyprctl clients' showed
TARGET_CLASS="spotify"
EXEC_CMD="spotify"

# Find the window's unique address
ADDRESS=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$TARGET_CLASS\") | .address" | head -n 1)

if [ -z "$ADDRESS" ]; then
    # If not running, start it
    $EXEC_CMD &
else
    # 1. Pull the window to your CURRENT workspace (+0)
    # hyprctl dispatch movetoworkspace "+0,address:$ADDRESS"

    # 2. Focus it
    hyprctl dispatch focuswindow "address:$ADDRESS"

    # 3. Maximize it (fullscreen mode 1 keeps the bar visible)
    hyprctl dispatch fullscreen 1
fi
