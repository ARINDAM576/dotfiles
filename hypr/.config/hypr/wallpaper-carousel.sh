#!/usr/bin/env bash

# Directory containing your eye-candy wallpapers
WP_DIR="$HOME/Pictures/wallpapers"
# Interval between carousel shifts (e.g., 300 seconds / 5 minutes)
INTERVAL=300

# Ensure the awww daemon is active
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 0.5
fi

# Infinite loop for the pure carousel
while true; do
    # Select a random wallpaper from the directory
    NEXT_WP=$(find "$WP_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) | shuf -n 1)

    if [ -n "$NEXT_WP" ]; then
        # Direct, max-performance eyecandy transition
        awww img "$NEXT_WP" \
            --transition-type wave \
            --transition-angle 30 \
            --transition-fps 60 \
            --transition-duration 2 \
            --transition-wave 20,20
    fi

    sleep "$INTERVAL"
done
