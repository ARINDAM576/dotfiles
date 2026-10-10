#!/usr/bin/env bash

if [[ -d "/sys/class/power_supply/BAT0" || -d "/sys/class/power_supply/BAT1" ]]; then

else
    # Desktop PC fallback: AC Power Plug, no sliding percentage
    printf '{"text": "󰚥", "tooltip": "AC Power Connected (Desktop)", "class": "desktop"}\n'
fi
