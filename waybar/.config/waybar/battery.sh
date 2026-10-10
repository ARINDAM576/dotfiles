#!/usr/bin/env bash

if ! [[ -d "/sys/class/power_supply/BAT0" || -d "/sys/class/power_supply/BAT1" ]]; then
    # Desktop PC fallback
    printf '{"text": "  ", "tooltip": "AC Power Connected (Desktop)", "class": "desktop"}\n'
else
    # Laptop fallback: Output empty text so Waybar safely hides it
    printf '{"text": "", "tooltip": "", "class": "laptop"}\n'
fi
