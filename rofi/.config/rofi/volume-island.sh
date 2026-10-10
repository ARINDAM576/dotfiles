#!/usr/bin/env bash
# Dynamic-island style audio control popup for Hyprland + rofi.
# Catppuccin Mocha themed. Bound to the waybar pulseaudio module's on-click.
#
# Main view: Output (volume + mute + device/port name), Input (same),
# Open Mixer. Enter on Output/Input swaps into a flat device+port picker
# (same shape as pavucontrol's output/input combo box - each port of a
# multi-port device, e.g. Headphones vs Line Out, is its own row).
# Picking one, or "Back", returns to the main view.
#
# Device/port enumeration and switching goes through `pactl` (PulseAudio
# compat layer), since `wpctl` only knows about devices, not the
# individual ports within one - that's pactl's territory. Volume and mute
# stay on `wpctl`, unchanged.
#
# Controls:
#   Up/Down     - move between rows
#   Left/Right  - volume down/up (5%) - main view, Output/Input rows only
#   m           - toggle mute - main view, Output/Input rows only
#   Enter       - Output/Input: open device+port picker | Mixer: launch pavucontrol
#                 In a picker: select that device/port as default, or "Back"
#   Esc         - closes the popup entirely, from any view

MODI_NAME="volume-island"
RASI="$HOME/.config/rofi/volume-island.rasi"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/volume-island.view"
SEP=$'\x1e'   # internal field separator for info tags - never appears in real device/port names

# ---------------------------------------------------------------------------
# LAUNCHER
# ---------------------------------------------------------------------------
if [ -z "${ROFI_RETV+x}" ]; then
    if pgrep -f -- "-show $MODI_NAME" > /dev/null; then
        pkill -f -- "-show $MODI_NAME"
        exit 0
    fi
    echo "main" > "$STATE_FILE"
    exec rofi -modi "$MODI_NAME:$0" -show "$MODI_NAME" \
        -theme "$RASI" \
        -kb-move-char-back "" -kb-move-char-forward "" \
        -kb-row-left "" -kb-row-right "" \
        -kb-custom-1 "Left" \
        -kb-custom-2 "Right" \
        -kb-custom-3 "m"
fi

# ---------------------------------------------------------------------------
# MODE BACKEND
# ---------------------------------------------------------------------------

ICON_VOL_HIGH="󰕾"
ICON_VOL_MED="󰖀"
ICON_VOL_LOW="󰕿"
ICON_VOL_MUTE="󰝟"
ICON_MIC_ON="󰍬"
ICON_MIC_MUTE="󰍭"
ICON_MIXER="󰕵"

BAR_WIDTH=10
COL_FILL="#cba6f7"
COL_HANDLE="#f5e0dc"
COL_TRACK="#585b70"

trunc() {
    local s="$1" n="$2"
    if (( ${#s} > n )); then printf '%s…' "${s:0:n-1}"; else printf '%s' "$s"; fi
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

get_state() {
    local raw vol muted
    raw=$(wpctl get-volume "$1" 2>/dev/null || echo "Volume: 0.00")
    vol=$(awk '{printf "%d", $2 * 100}' <<< "$raw")
    if grep -q MUTED <<< "$raw"; then muted=1; else muted=0; fi
    echo "$vol $muted"
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

# TSV per row: name \t portid \t device_desc \t display_label \t is_active(1/0)
# One row per port; devices with no distinct ports get a single row with
# portid empty and display_label == device_desc.
list_output_options() {
    pactl list sinks | awk -v DEF="$(pactl get-default-sink 2>/dev/null)" '
        function flush(   i, isact) {
            if (name == "") return
            if (ports_n == 0) {
                isact = (name==DEF) ? "1" : "0"
                print name "\t" "" "\t" desc "\t" desc "\t" isact
            } else {
                for (i=1; i<=ports_n; i++) {
                    isact = (name==DEF && port_ids[i]==active) ? "1" : "0"
                    print name "\t" port_ids[i] "\t" desc "\t" (desc " — " port_labels[i]) "\t" isact
                }
            }
        }
        BEGIN { name=""; desc=""; active=""; inports=0; ports_n=0 }
        /^Sink #/ { flush(); name=""; desc=""; active=""; inports=0; ports_n=0; next }
        /^\tName: / { name=$0; sub(/^\tName: /,"",name); next }
        /^\tDescription: / { desc=$0; sub(/^\tDescription: /,"",desc); next }
        /^\tPorts:/ { inports=1; next }
        /^\tActive Port: / { active=$0; sub(/^\tActive Port: /,"",active); inports=0; next }
        /^\t[A-Za-z]/ { inports=0 }
        inports && /^\t\t/ {
            line=$0; sub(/^\t\t/,"",line)
            if (line ~ /available: no/) next
            colon = index(line, ": ")
            if (colon==0) next
            pid = substr(line, 1, colon-1)
            rest = substr(line, colon+2)
            paren = index(rest, " (")
            lbl = (paren>0) ? substr(rest, 1, paren-1) : rest
            ports_n++
            port_ids[ports_n]=pid
            port_labels[ports_n]=lbl
            next
        }
        END { flush() }
    '
}

list_input_options() {
    pactl list sources | awk -v DEF="$(pactl get-default-source 2>/dev/null)" '
        function flush(   i, isact) {
            if (name == "") return
            if (desc ~ /^Monitor of /) return
            if (ports_n == 0) {
                isact = (name==DEF) ? "1" : "0"
                print name "\t" "" "\t" desc "\t" desc "\t" isact
            } else {
                for (i=1; i<=ports_n; i++) {
                    isact = (name==DEF && port_ids[i]==active) ? "1" : "0"
                    print name "\t" port_ids[i] "\t" desc "\t" (desc " — " port_labels[i]) "\t" isact
                }
            }
        }
        BEGIN { name=""; desc=""; active=""; inports=0; ports_n=0 }
        /^Source #/ { flush(); name=""; desc=""; active=""; inports=0; ports_n=0; next }
        /^\tName: / { name=$0; sub(/^\tName: /,"",name); next }
        /^\tDescription: / { desc=$0; sub(/^\tDescription: /,"",desc); next }
        /^\tPorts:/ { inports=1; next }
        /^\tActive Port: / { active=$0; sub(/^\tActive Port: /,"",active); inports=0; next }
        /^\t[A-Za-z]/ { inports=0 }
        inports && /^\t\t/ {
            line=$0; sub(/^\t\t/,"",line)
            if (line ~ /available: no/) next
            colon = index(line, ": ")
            if (colon==0) next
            pid = substr(line, 1, colon-1)
            rest = substr(line, colon+2)
            paren = index(rest, " (")
            lbl = (paren>0) ? substr(rest, 1, paren-1) : rest
            ports_n++
            port_ids[ports_n]=pid
            port_labels[ports_n]=lbl
            next
        }
        END { flush() }
    '
}

view=$(cat "$STATE_FILE" 2>/dev/null || echo main)
SELECTED_INFO="${ROFI_INFO:-}"

case "${ROFI_RETV:-0}" in
    0)
        printf '\0use-hot-keys\x1ftrue\n'
        printf '\0no-custom\x1ftrue\n'
        printf '\0markup-rows\x1ftrue\n'
        ;;
    1)  # Enter
        case "$view" in
            main)
                case "$SELECTED_INFO" in
                    main:output) view="switch-output"; echo "$view" > "$STATE_FILE" ;;
                    main:input)  view="switch-input";  echo "$view" > "$STATE_FILE" ;;
                    main:mixer)
                        if command -v pavucontrol > /dev/null; then
                            coproc ( pavucontrol > /dev/null 2>&1 )
                        fi
                        exit 0
                        ;;
                esac
                ;;
            switch-output)
                case "$SELECTED_INFO" in
                    back) : ;;
                    switchout*)
                        rest="${SELECTED_INFO#switchout}"
                        IFS="$SEP" read -r sname sport <<< "$rest"
                        pactl set-default-sink "$sname"
                        [ -n "$sport" ] && pactl set-sink-port "$sname" "$sport"
                        ;;
                esac
                view="main"; echo "$view" > "$STATE_FILE"
                ;;
            switch-input)
                case "$SELECTED_INFO" in
                    back) : ;;
                    switchin*)
                        rest="${SELECTED_INFO#switchin}"
                        IFS="$SEP" read -r sname sport <<< "$rest"
                        pactl set-default-source "$sname"
                        [ -n "$sport" ] && pactl set-source-port "$sname" "$sport"
                        ;;
                esac
                view="main"; echo "$view" > "$STATE_FILE"
                ;;
        esac
        ;;
    10) # Left -> volume down
        if [ "$view" = "main" ]; then
            case "$SELECTED_INFO" in
                main:output) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
                main:input)  wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- ;;
            esac
        fi
        ;;
    11) # Right -> volume up
        if [ "$view" = "main" ]; then
            case "$SELECTED_INFO" in
                main:output) wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
                main:input)  wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 5%+ ;;
            esac
        fi
        ;;
    12) # m -> toggle mute
        if [ "$view" = "main" ]; then
            case "$SELECTED_INFO" in
                main:output) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
                main:input)  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
            esac
        fi
        ;;
esac

printf '\0keep-selection\x1ftrue\n'
view=$(cat "$STATE_FILE" 2>/dev/null || echo main)

case "$view" in
    switch-output)
        printf '\0prompt\x1fOutput\n'
        printf '\0message\x1f ↵ select   Esc close\n'
        mapfile -t opts < <(list_output_options)
        n=$(( ${#opts[@]} + 1 )); (( n > 8 )) && n=8
        printf '\0theme\x1flistview { lines: %d; }\n' "$n"
        printf '← Back\0info\x1fback\n'
        idx=1; defidx=0
        for line in "${opts[@]}"; do
            IFS=$'\t' read -r sname pid desc lbl isact <<< "$line"
            [ -z "$sname" ] && continue
            marker="○"
            if [ "$isact" = "1" ]; then marker="●"; defidx=$idx; fi
            disp=$(trunc "$lbl" 36)
            printf '%s  %s\0info\x1fswitchout%s%s%s\n' "$marker" "$disp" "$sname" "$SEP" "$pid"
            idx=$((idx+1))
        done
        printf '\0new-selection\x1f%d\n' "$defidx"
        ;;
    switch-input)
        printf '\0prompt\x1fInput\n'
        printf '\0message\x1f ↵ select   Esc close\n'
        mapfile -t opts < <(list_input_options)
        n=$(( ${#opts[@]} + 1 )); (( n > 8 )) && n=8
        printf '\0theme\x1flistview { lines: %d; }\n' "$n"
        printf '← Back\0info\x1fback\n'
        idx=1; defidx=0
        for line in "${opts[@]}"; do
            IFS=$'\t' read -r sname pid desc lbl isact <<< "$line"
            [ -z "$sname" ] && continue
            marker="○"
            if [ "$isact" = "1" ]; then marker="●"; defidx=$idx; fi
            disp=$(trunc "$lbl" 36)
            printf '%s  %s\0info\x1fswitchin%s%s%s\n' "$marker" "$disp" "$sname" "$SEP" "$pid"
            idx=$((idx+1))
        done
        printf '\0new-selection\x1f%d\n' "$defidx"
        ;;
    *)
        printf '\0prompt\x1fAudio\n'
        printf '\0message\x1f ⇅ move   ⇆ vol   m mute   ↵ switcher/mixer           Esc close\n'
        printf '\0theme\x1flistview { lines: 3; }\n'

        read -r OUT_VOL OUT_MUTED <<< "$(get_state @DEFAULT_AUDIO_SINK@)"
        read -r IN_VOL IN_MUTED <<< "$(get_state @DEFAULT_AUDIO_SOURCE@)"

        OUT_NAME=$(list_output_options | awk -F'\t' '$5=="1"{print $3; exit}')
        IN_NAME=$(list_input_options   | awk -F'\t' '$5=="1"{print $3; exit}')
        [ -z "$OUT_NAME" ] && OUT_NAME="Default"
        [ -z "$IN_NAME" ]  && IN_NAME="Default"

        o_icon=$(vol_icon "$OUT_VOL" "$OUT_MUTED")
        i_icon=$(mic_icon "$IN_MUTED")
        o_bar=$(render_bar "$OUT_VOL" "$OUT_MUTED")
        i_bar=$(render_bar "$IN_VOL" "$IN_MUTED")
        o_name=$(trunc "$OUT_NAME" 20)
        i_name=$(trunc "$IN_NAME" 20)

        printf '%s  %-15s %s %3d%%   -▸\0info\x1fmain:output\n' "$o_icon" "$o_name" " $o_bar" "$OUT_VOL"
        printf '%s  %-15s %s %3d%%   -▸\0info\x1fmain:input\n'  "$i_icon" "$i_name" " $i_bar" "$IN_VOL"
        printf '%s  Open Sound Mixer\0info\x1fmain:mixer\n' "$ICON_MIXER"
        ;;
esac
