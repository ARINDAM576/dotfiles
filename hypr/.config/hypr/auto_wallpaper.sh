#!/usr/bin/env bash

# 1. SCAN FOR ANY WALLPAPER IMAGE IN YOUR TARGET DIRECTORY
WALLPAPER_DIR="$HOME/Pictures/current_wallpaper"

shopt -s nullglob
WALLPAPERS=("$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp})
shopt -u nullglob

if [ ${#WALLPAPERS[@]} -gt 0 ]; then
    ORIGINAL_WP="${WALLPAPERS}"
    EXT="${ORIGINAL_WP##*.}"
    DIMMED_WP="/tmp/dimmed_wallpaper.${EXT}"
else
    echo "No valid(.png, .jpg, .jpeg, .webp) wallpaper images found in $WALLPAPER_DIR"
    exit 1
fi

# 2. START HYPRPAPER DAEMON IN BACKGROUND IF NOT RUNNING
if ! pgrep -x "hyprpaper" > /dev/null; then
    hyprpaper &
    sleep 0.4
fi

# 3. AUTO-IDENTIFY THE ACTIVE MONITOR DYNAMICALLY
MONITOR=$(hyprctl monitors -j | jq -r '. | select(.focused == true) | .name')
if [ -z "$MONITOR" ] || [ "$MONITOR" = "null" ]; then
    MONITOR=$(hyprctl monitors -j | jq -r '..name')
fi

# 4. GENERATE ON BOOT (Slight 28% dim)
magick "$ORIGINAL_WP" -strip -fill black -colorize 28% "$DIMMED_WP"

# Clean initial state check using visible client filter instead of raw windows property
VISIBLE_WINDOWS=$(hyprctl clients -j | jq "[[] | select(.workspace.name == \"$(hyprctl activeworkspace -j | jq -r '.name')\" and .hidden == false)] | length")

if [ "$VISIBLE_WINDOWS" -gt  ]; then
    hyprctl hyprpaper reload "$MONITOR,$DIMMED_WP"
    STATE="dimmed"
else
    hyprctl hyprpaper reload "$MONITOR,$ORIGINAL_WP"
    STATE="bright"
fi

# 5. RUNTIME WINDOW LISTENER LOGIC (Instant swapping, zero animations)
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    # Only react to actual workspace transitions, window maps, or window unmaps
    if [[ "$line" == *"openwindow"* || "$line" == *"closewindow"* || "$line" == *"workspace"* ]]; then

        # Pull only actual, non-hidden user client windows on the current focused workspace
        CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.name')
        VISIBLE_WINDOWS=$(hyprctl clients -j | jq "[[] | select(.workspace.name == \"$CURRENT_WS\" and .hidden == false)] | length")

        if [ "$VISIBLE_WINDOWS" -gt  ]; then
            if [ "$STATE" != "dimmed" ]; then
                # The 'reload' command maps the wallpaper instantly without the fade animation
                hyprctl hyprpaper reload "$MONITOR,$DIMMED_WP"
                STATE="dimmed"
            fi
        else
            if [ "$STATE" != "bright" ]; then
                # The 'reload' command maps the wallpaper instantly without the fade animation
                hyprctl hyprpaper reload "$MONITOR,$ORIGINAL_WP"
                STATE="bright"
            fi
        fi
    fi
done
