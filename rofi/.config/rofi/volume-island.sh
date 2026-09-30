#!/usr/bin/env bash
# Dynamic-island style audio control popup for Hyprland + rofi.
# Catppuccin Mocha themed. Bound to the waybar pulseaudio module's on-click.
#
# Controls once open:
#   Up/Down   - move between Output / Input / Open Mixer
#   Left/Right - volume down/up (5%) on the highlighted row
#   m          - toggle mute on the highlighted row
#   Enter      - on "Open Mixer" launches pavucontrol; elsewhere just selects
#   Esc        - closes the popup

#  ⇅ move   ⇆ vol   m mute                 Esc close
#!/usr/bin/env bash
# Dynamic-island style audio control popup for Hyprland + rofi.
# Catppuccin Mocha themed. Bound to the waybar pulseaudio module's on-click.
#
# Implemented as a rofi SCRIPT MODE (not repeated -dmenu calls), so the
# window stays open and just redraws in place on every keypress - no
# close/reopen flicker.
#
# Controls once open:
#   Up/Down    - move between Output / Input / Open Mixer
#   Left/Right - volume down/up (5%) on the highlighted row
#   m          - toggle mute on the highlighted row
#   Enter      - toggles mute on Output/Input; launches pavucontrol on "Open Mixer"
#   Esc        - closes the popup

MODI_NAME="volume-island"
RASI="$HOME/.config/rofi/volume-island.rasi"

# ---------------------------------------------------------------------------
# LAUNCHER: this branch runs when waybar invokes the script directly.
# ROFI_RETV is only ever set by rofi itself when it calls this same file
# back as the mode backend, so its absence means "we were just clicked".
# ---------------------------------------------------------------------------
if [ -z "${ROFI_RETV+x}" ]; then
    if pgrep -f -- "-show $MODI_NAME" > /dev/null; then
        pkill -f -- "-show $MODI_NAME"
        exit 0
    fi
    exec rofi -modi "$MODI_NAME:$0" -show "$MODI_NAME" \
        -theme "$RASI" \
        -kb-move-char-back "" -kb-move-char-forward "" \
        -kb-row-left "" -kb-row-right "" \
        -kb-custom-1 "Left" \
        -kb-custom-2 "Right" \
        -kb-custom-3 "m"
fi

# ---------------------------------------------------------------------------
# MODE BACKEND: everything below runs once per rofi event (open, arrow
# press, mute toggle, enter...). Rofi keeps the same window alive across
# these calls, so nothing here should try to relaunch rofi.
# ---------------------------------------------------------------------------

# --- icons (Nerd Font mdi range - same family as your battery/network icons) ---
ICON_VOL_HIGH="󰕾"
ICON_VOL_MED="󰖀"
ICON_VOL_LOW="󰕿"
ICON_VOL_MUTE="󰝟"
ICON_MIC_ON="󰍬"
ICON_MIC_MUTE="󰍭"
ICON_MIXER="󰕵"

BAR_WIDTH=18
COL_FILL="#cba6f7"    # mauve
COL_HANDLE="#f5e0dc"  # rosewater
COL_TRACK="#585b70"   # surface2

get_state() {
    # $1 = @DEFAULT_AUDIO_SINK@ or @DEFAULT_AUDIO_SOURCE@
    local raw vol muted
    raw=$(wpctl get-volume "$1" 2>/dev/null || echo "Volume: 0.00")
    vol=$(awk '{printf "%d", $2 * 100}' <<< "$raw")
    if grep -q MUTED <<< "$raw"; then muted=1; else muted=0; fi
    echo "$vol $muted"
}

render_bar() {
    local vol=$1 muted=$2
    local filled i bar fill_col
    filled=$(( vol * BAR_WIDTH / 100 ))
    (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
    fill_col=$COL_FILL
    (( muted )) && fill_col=$COL_TRACK
    bar=""
    for (( i=0; i<BAR_WIDTH; i++ )); do
        if (( i < filled )); then
            bar+="<span foreground='${fill_col}'>━</span>"
        elif (( i == filled )); then
            bar+="<span foreground='${COL_HANDLE}'>●</span>"
        else
            bar+="<span foreground='${COL_TRACK}'>─</span>"
        fi
    done
    echo "$bar"
}

vol_icon() {
    local vol=$1 muted=$2
    if (( muted )); then echo "$ICON_VOL_MUTE"
    elif (( vol >= 65 )); then echo "$ICON_VOL_HIGH"
    elif (( vol >= 30 )); then echo "$ICON_VOL_MED"
    else echo "$ICON_VOL_LOW"
    fi
}

mic_icon() {
    local muted=$1
    if (( muted )); then echo "$ICON_MIC_MUTE"; else echo "$ICON_MIC_ON"; fi
}

# Which row was active when this event fired. Rofi sets ROFI_INFO from the
# row's "info" tag; $1 (the row's display text) is a fallback in case some
# rofi version doesn't carry ROFI_INFO through custom keybindings.
SELECTED_INFO="${ROFI_INFO:-}"
if [ -z "$SELECTED_INFO" ]; then
    case "${1:-}" in
        *Output*) SELECTED_INFO="output" ;;
        *Input*)  SELECTED_INFO="input" ;;
        *Mixer*)  SELECTED_INFO="mixer" ;;
    esac
fi

case "${ROFI_RETV:-0}" in
    0)  # first draw - set mode options once
        printf '\0use-hot-keys\x1ftrue\n'
        printf '\0no-custom\x1ftrue\n'
        printf '\0markup-rows\x1ftrue\n'
        printf '\0prompt\x1fAudio\n'
        printf '\0message\x1f ⇅ move   ⇆ vol   m mute                 Esc close'
        ;;
    1)  # Enter
        case "$SELECTED_INFO" in
            output) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            input)  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
            mixer)
                coproc ( pavucontrol > /dev/null 2>&1 )
                exit 0
                ;;
        esac
        ;;
    10) # Left -> volume down
        case "$SELECTED_INFO" in
            output) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
            input)  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- ;;
        esac
        ;;
    11) # Right -> volume up
        case "$SELECTED_INFO" in
            output) wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
            input)  wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 5%+ ;;
        esac
        ;;
    12) # m -> toggle mute
        case "$SELECTED_INFO" in
            output) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            input)  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
        esac
        ;;
esac

# Keep the highlighted row in place across redraws instead of snapping back to row 0
printf '\0keep-selection\x1ftrue\n'

read -r OUT_VOL OUT_MUTED <<< "$(get_state @DEFAULT_AUDIO_SINK@)"
read -r IN_VOL IN_MUTED <<< "$(get_state @DEFAULT_AUDIO_SOURCE@)"

o_icon=$(vol_icon "$OUT_VOL" "$OUT_MUTED")
i_icon=$(mic_icon "$IN_MUTED")
o_bar=$(render_bar "$OUT_VOL" "$OUT_MUTED")
i_bar=$(render_bar "$IN_VOL" "$IN_MUTED")

printf '%s  Output   %s  %3d%%\0info\x1foutput\n' "$o_icon" "$o_bar" "$OUT_VOL"
printf '%s  Input    %s  %3d%%\0info\x1finput\n' "$i_icon" "$i_bar" "$IN_VOL"
printf '%s  Open Sound Mixer\0info\x1fmixer\n' "$ICON_MIXER"
