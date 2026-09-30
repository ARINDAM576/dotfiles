#!/usr/bin/env bash

# Function to play sound at a specific volume (0-65536)
# Lowering UI sounds to 40% (26000) so they aren't deafening
play_ui() {
    paplay "$1" &
}

# The folder where you stored your sounds
SND_DIR="/home/arindamlegend/.config/hypr/sounds"

handle() {
  case $1 in
    openwindow*)     play_ui "$SND_DIR/open.mp3" ;;
    closewindow*)    play_ui "$SND_DIR/close.wav" ;;
    workspace*)      play_ui "$SND_DIR/switch.wav" ;;
    focusedmon*)     play_ui "$SND_DIR/monitor.wav" ;;
    fullscreen*)     play_ui "$SND_DIR/fullscreen.wav" ;;
    floating*)       play_ui "$SND_DIR/float.wav" ;;
  esac
}

# Ensure socat is installed
if ! command -v socat &> /dev/null; then
    notify-send "Sound Script" "Please install 'socat' for sounds to work"
    exit 1
fi

# Listen to the Hyprland event socket
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do handle "$line"; done
