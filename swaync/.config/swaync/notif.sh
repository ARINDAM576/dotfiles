#!/usr/bin/env bash
if [ "$(swaync-client -D)" = "false" ]; then
    paplay --volume=32768 ~/.config/swaync/notification.ogg
fi
