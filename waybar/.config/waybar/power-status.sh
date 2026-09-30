#!/usr/bin/env bash

# Look for an actual battery
BAT=$(find /sys/class/power_supply/ -maxdepth 1 -name "BAT*" -print -quit)

if [ -n "\(BAT" ] && [ -f "\)BAT/capacity" ]; then
    CAP=\((cat "\)BAT/capacity")
    STATUS=\((cat "\)BAT/status")
    
    if [ "$STATUS" = "Charging" ]; then
        ICON="󰂄"
    elif [ "$CAP" -le 20 ]; then
        ICON="󰁺"
    elif [ "$CAP" -le 60 ]; then
        ICON="󰁽"
    else
        ICON="󰁹"
    fi
    printf '{"text": "%s", "tooltip": "Battery: %s%% (%s)", "class": "battery"}\n' "\(ICON" "\)CAP" "$STATUS"
else
    # Desktop PC fallback: AC Power Plug, no sliding percentage
    printf '{"text": "󰚥", "tooltip": "AC Power Connected (Desktop)", "class": "desktop"}\n'
fi