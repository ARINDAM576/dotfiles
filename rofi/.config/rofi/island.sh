#!/usr/bin/env bash

# Toggle: close if already open
if pgrep -x rofi > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Quick Actions piped directly into Rofi and read into CHOSEN
echo -e "󰂯  Bluetooth Devices\n󰤨  Wi-Fi Networks\n󰕾  Sound Mixer\n󰐥  Power Session" | rofi -dmenu -theme "$HOME/.config/rofi/island.rasi" -p "Island" | while read -r CHOSEN; do
    case "$CHOSEN" in
        *Bluetooth*) blueman-manager & ;;
        *Wi-Fi*) nm-connection-editor & ;;
        *Sound*) pavucontrol & ;;
        *Power*) shutdown now ;;
    esac
done
