#!/usr/bin/env bash

CACHE_FILE="/dev/shm/waybar_brightness"
TARGET_FILE="/dev/shm/waybar_brightness_target"
LOCK_FILE="/dev/shm/waybar_brightness.lock"
AUTO_FLAG="/dev/shm/waybar_brightness_auto"
PID_FILE="/dev/shm/waybar.pid"

is_laptop() {
  [ -d /sys/class/backlight ] && [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ]
}

get_hw_brightness() {
  if is_laptop; then
    brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}'
  else
    ddcutil getvcp 10 --sleep-multiplier .1 2>/dev/null | grep -oP 'current value =\s*\K[0-9]+'
  fi
}

# Asynchronous debounced hardware worker
apply_desktop_hw() {
  (
    flock -n 9 || exit 0
    local last_applied=""
    while true; do
      target=$(cat "$TARGET_FILE" 2>/dev/null)
      [ -z "$target" ] && break
      if [ "$target" != "$last_applied" ]; then
        ddcutil setvcp 10 "$target" --noverify --sleep-multiplier .1 >/dev/null 2>&1
        last_applied="$target"
      else
        break
      fi
    done
  ) 9>"$LOCK_FILE" & disown
}

# Fast signal: bypasses /proc scanning
signal_waybar() {
  local pid=""
  if [ -f "$PID_FILE" ]; then
    pid=$(< "$PID_FILE")
  fi
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    pid=$(pidof -s waybar 2>/dev/null)
    [ -n "$pid" ] && echo "$pid" > "$PID_FILE"
  fi
  [ -n "$pid" ] && kill -RTMIN+8 "$pid" 2>/dev/null
}

case "$1" in
  get)
    # Instant read from RAM
    if [ -f "$CACHE_FILE" ]; then
      val=$(< "$CACHE_FILE")
    else
      val=$(get_hw_brightness)
      val=${val:-50}
      echo "$val" > "$CACHE_FILE"
    fi

    # Zero-syscall flag check in RAM
    if [ -f "$AUTO_FLAG" ]; then
      alt="auto"
      class="auto"
      tooltip="Auto-Brightness: ON (Left-Click)\\nBrightness: ${val}% (Scroll)"
    else
      alt="default"
      class="manual"
      tooltip="Auto-Brightness: OFF (Left-Click)\\nBrightness: ${val}% (Scroll)"
    fi

    printf '{"text": "%s%%", "percentage": %d, "alt": "%s", "tooltip": "%s", "class": "%s"}\n' \
      "$val" "$val" "$alt" "$tooltip" "$class"
    ;;

  up|down)
    # 1. Pure RAM calculation (<0.1ms)
    if [ -f "$CACHE_FILE" ]; then
      val=$(< "$CACHE_FILE")
    else
      val=50
    fi

    if [ "$1" = "up" ]; then
      val=$((val + 5))
      [ "$val" -gt 100 ] && val=100
    else
      val=$((val - 5))
      [ "$val" -lt 0 ] && val=0
    fi

    # 2. Write to RAM
    echo "$val" > "$CACHE_FILE"
    echo "$val" > "$TARGET_FILE"

    # 3. Repaint UI immediately
    signal_waybar

    # 4. Push to hardware in the background without blocking
    if is_laptop; then
      brightnessctl set "${val}%" >/dev/null 2>&1 &
    else
      apply_desktop_hw
    fi
    ;;

  toggle-auto)
    if [ -f "$AUTO_FLAG" ]; then
      rm -f "$AUTO_FLAG"
      if systemctl --user is-active --quiet wluma 2>/dev/null; then
        systemctl --user stop wluma
      fi
      pkill -x wluma 2>/dev/null
      notify-send -u low -i display-brightness-symbolic "Auto-Brightness" "Disabled"
    else
      touch "$AUTO_FLAG"
      if systemctl --user list-unit-files wluma.service 2>/dev/null | grep -q wluma.service; then
        systemctl --user start wluma
      else
        wluma >/dev/null 2>&1 & disown
      fi
      notify-send -u low -i display-brightness-symbolic "Auto-Brightness" "Enabled"
    fi

    signal_waybar
    ;;
esac
