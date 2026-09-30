#!/usr/bin/env bash

# --- 1. Helper: Clean Percentage (No Icons/Badges) ---
format_batt() {
    local val="$1"
    [ -z "$val" ] && return
    local num="${val//%/}"
    local color="#a6e3a1" # Vivid Mint Green

    if [ "$num" -le 20 ]; then
        color="#f38ba8" # Vivid Red
    elif [ "$num" -le 50 ]; then
        color="#fab387" # Vivid Peach
    elif [ "$num" -le 80 ]; then
        color="#f9e2af" # Vivid Yellow
    fi
    printf " <span color='%s' font_weight='bold'>(%s%%)</span>" "$color" "$num"
}

# --- 2. Query Output (Sink) ---
sink_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
sink_vol=$(echo "$sink_raw" | awk '{print int($2 * 100)}')
sink_muted=$(echo "$sink_raw" | grep -q "\[MUTED\]" && echo "yes" || echo "no")
out_desc=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'= ' '/node.description/ {gsub(/"/, "", $2); print $2; exit}')
out_desc="${out_desc:-Default Output}"

out_bt_mac=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'= ' '/api.bluez5.address/ {gsub(/"/, "", $2); print $2; exit}')
out_batt=""
if [ -n "$out_bt_mac" ]; then
    batt_pct=$(bluetoothctl info "$out_bt_mac" 2>/dev/null | awk -F'[()]' '/Battery Percentage/ {print $2}')
    if [ -z "$batt_pct" ]; then
        batt_pct=$(upower -i /org/freedesktop/UPower/devices/headset_dev_"${out_bt_mac//:/_}" 2>/dev/null | awk '/percentage:/ {print $2}' | tr -d '%')
    fi
    [ -n "$batt_pct" ] && out_batt=$(format_batt "$batt_pct")
fi

# --- 3. Query Input (Source) ---
source_raw=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
source_muted=$(echo "$source_raw" | grep -q "\[MUTED\]" && echo "yes" || echo "no")
in_desc=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk -F'= ' '/node.description/ {gsub(/"/, "", $2); print $2; exit}')
in_desc="${in_desc:-Default Input}"

in_bt_mac=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk -F'= ' '/api.bluez5.address/ {gsub(/"/, "", $2); print $2; exit}')
in_batt=""
if [ -n "$in_bt_mac" ]; then
    batt_pct=$(bluetoothctl info "$in_bt_mac" 2>/dev/null | awk -F'[()]' '/Battery Percentage/ {print $2}')
    if [ -z "$batt_pct" ]; then
        batt_pct=$(upower -i /org/freedesktop/UPower/devices/headset_dev_"${in_bt_mac//:/_}" 2>/dev/null | awk '/percentage:/ {print $2}' | tr -d '%')
    fi
    [ -n "$batt_pct" ] && in_batt=$(format_batt "$batt_pct")
fi

# --- 4. Waybar Pill Text ---
if [ "$sink_muted" = "yes" ]; then
    vol_icon=""
    bar_text=""
    css_class="muted"
else
    if [ "$sink_vol" -ge 65 ]; then
        vol_icon=""
    elif [ "$sink_vol" -ge 25 ]; then
        vol_icon=""
    else
        vol_icon=""
    fi
    bar_text="${sink_vol}% ${vol_icon}"
    css_class="unmuted"
fi

if [ -n "$out_bt_mac" ]; then
    bar_text="${bar_text}"
fi

if [ "$source_muted" = "yes" ]; then
    bar_text="${bar_text} "
fi

# --- 5. High-Contrast Pango Tooltip ---
if [ "$sink_muted" = "yes" ]; then
    vol_val="<span color='#f38ba8' font_weight='bold'>MUTED</span> <span color='#a6adc8'>(${sink_vol}%)</span>"
else
    vol_val="<span color='#89dceb' font_weight='bold'>${sink_vol}%</span>"
fi

if [ "$source_muted" = "yes" ]; then
    mic_val="<span color='#f38ba8' font_weight='bold'>MUTED</span>"
else
    mic_val="<span color='#a6e3a1' font_weight='bold'>LIVE</span>"
fi

tooltip="<span color='#f5c2e7' font_weight='bold'>󰓃 OUTPUT:</span> <span color='#ffffff' font_weight='bold'>${out_desc}</span>${out_batt}
  <span color='#b4befe'>Volume:</span> ${vol_val}

<span color='#94e2d5' font_weight='bold'>󰍬 INPUT:</span>  <span color='#ffffff' font_weight='bold'>${in_desc}</span>${in_batt}
  <span color='#b4befe'>Mic:</span>    ${mic_val}

<span color='#585b70'>──────────────────────────────────────────</span>
<span color='#fab387' font_weight='bold'>Left-Click:</span>   <span color='#cdd6f4'>Open Pavucontrol</span>
<span color='#fab387' font_weight='bold'>Middle-Click:</span> <span color='#cdd6f4'>Toggle Output Mute</span>
<span color='#fab387' font_weight='bold'>Right-Click:</span>  <span color='#cdd6f4'>Toggle Mic Mute</span>
<span color='#fab387' font_weight='bold'>Scroll:</span>       <span color='#cdd6f4'>Adjust Volume (±5%)</span>"

# Export formatted JSON
jq -nc \
    --arg text "$bar_text" \
    --arg tooltip "$tooltip" \
    --arg class "$css_class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
