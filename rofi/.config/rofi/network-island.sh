#!/usr/bin/env bash
# Dynamic-island style network control popup for Hyprland + rofi.
# Catppuccin Mocha themed. Bound to the waybar network module's on-click.
# Same rofi script-mode architecture as volume-island.sh (stays open,
# redraws in place - no close/reopen flicker).
#
# Controls once open:
#   Up/Down - move between Wifi / Ethernet / VPN / Open Network Manager
#   Enter or m - toggle whichever row is highlighted
#   Enter on "Open Network Manager" - launches networkmanager_dmenu
#   Esc - closes the popup
#
# VPN: auto-detects the first NetworkManager connection of type
# "wireguard" or "vpn" (e.g. an imported ProtonVPN WireGuard profile).
# If you have more than one and want a specific one, hardcode its name
# in VPN_NAME_OVERRIDE below.

MODI_NAME="network-island"
RASI="$HOME/.config/rofi/network-island.rasi"
VPN_NAME_OVERRIDE=""   # e.g. "protonvpn-us-free" - leave empty to auto-detect

# ---------------------------------------------------------------------------
# LAUNCHER
# ---------------------------------------------------------------------------
if [ -z "${ROFI_RETV+x}" ]; then
    if pgrep -f -- "-show $MODI_NAME" > /dev/null; then
        pkill -f -- "-show $MODI_NAME"
        exit 0
    fi
    exec rofi -modi "$MODI_NAME:$0" -show "$MODI_NAME" \
        -theme "$RASI" \
        -kb-custom-1 "m"
fi

# ---------------------------------------------------------------------------
# MODE BACKEND
# ---------------------------------------------------------------------------

ICON_WIFI_0="󰤯"
ICON_WIFI_1="󰤟"
ICON_WIFI_2="󰤢"
ICON_WIFI_3="󰤥"
ICON_WIFI_4="󰤨"
ICON_WIFI_OFF="󰤮"
ICON_ETHERNET="󰈀"
ICON_VPN_ON="󰦝"
ICON_VPN_OFF="󰦞"
ICON_MANAGER="󰖟"

BAR_WIDTH=10
COL_FILL="#89dceb"    # sky, matches your network module's accent
COL_HANDLE="#f5e0dc"  # rosewater
COL_TRACK="#585b70"   # surface2

render_bar() {
    local pct=$1
    local filled i bar
    filled=$(( pct * BAR_WIDTH / 100 ))
    (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
    bar=""
    for (( i=0; i<BAR_WIDTH; i++ )); do
        if (( i < filled )); then
            bar+="<span foreground='${COL_FILL}'>━</span>"
        elif (( i == filled )); then
            bar+="<span foreground='${COL_HANDLE}'>●</span>"
        else
            bar+="<span foreground='${COL_TRACK}'>─</span>"
        fi
    done
    echo "$bar"
}

get_wifi() {
    local radio line ssid signal
    radio=$(nmcli -t -f WIFI radio 2>/dev/null)
    if [ "$radio" != "enabled" ]; then
        echo "off||0"; return
    fi
    line=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '$1=="yes"{print; exit}')
    if [ -z "$line" ]; then
        echo "on||0"; return
    fi
    ssid=$(cut -d: -f2 <<< "$line")
    signal=$(cut -d: -f3 <<< "$line")
    echo "on|$ssid|$signal"
}

get_ethernet() {
    local line
    line=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2=="ethernet"{print; exit}')
    if [ -z "$line" ]; then
        echo "none||"; return
    fi
    echo "found|$(cut -d: -f1 <<< "$line")|$(cut -d: -f3 <<< "$line")"
}

get_vpn() {
    local name active
    if [ -n "$VPN_NAME_OVERRIDE" ]; then
        name="$VPN_NAME_OVERRIDE"
    else
        name=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="wireguard" || $2=="vpn"{print $1; exit}')
    fi
    if [ -z "$name" ]; then
        echo "none||"; return
    fi
    if nmcli -t -f NAME connection show --active 2>/dev/null | grep -Fxq "$name"; then
        active=1
    else
        active=0
    fi
    echo "found|$name|$active"
}

SELECTED_INFO="${ROFI_INFO:-}"
if [ -z "$SELECTED_INFO" ]; then
    case "${1:-}" in
        *Wifi*)    SELECTED_INFO="wifi" ;;
        *Ethernet*) SELECTED_INFO="ethernet" ;;
        *VPN*)     SELECTED_INFO="vpn" ;;
        *Manager*) SELECTED_INFO="manager" ;;
    esac
fi

case "${ROFI_RETV:-0}" in
    0)
        printf '\0use-hot-keys\x1ftrue\n'
        printf '\0no-custom\x1ftrue\n'
        printf '\0markup-rows\x1ftrue\n'
        printf '\0prompt\x1fNetwork\n'
        printf '\0message\x1f Enter/m toggle or open                     Esc close\n'
        ;;
    1|10)  # Enter or m
        case "$SELECTED_INFO" in
            wifi)
                IFS='|' read -r w_state _ _ <<< "$(get_wifi)"
                if [ "$w_state" = "off" ]; then nmcli radio wifi on; else nmcli radio wifi off; fi
                ;;
            ethernet)
                IFS='|' read -r e_found e_dev e_state <<< "$(get_ethernet)"
                if [ "$e_found" = "found" ]; then
                    if [ "$e_state" = "connected" ]; then
                        nmcli device disconnect "$e_dev"
                    else
                        nmcli device connect "$e_dev"
                    fi
                fi
                ;;
            vpn)
                IFS='|' read -r v_found v_name v_active <<< "$(get_vpn)"
                if [ "$v_found" = "found" ]; then
                    if [ "$v_active" = "1" ]; then
                        nmcli connection down "$v_name"
                    else
                        nmcli connection up "$v_name"
                    fi
                fi
                ;;
            manager)
                if [ "${ROFI_RETV:-0}" = "1" ]; then
                    if command -v networkmanager_dmenu > /dev/null; then
                        coproc ( networkmanager_dmenu > /dev/null 2>&1 )
                    else
                        coproc ( nm-connection-editor > /dev/null 2>&1 )
                    fi
                    exit 0
                fi
                ;;
        esac
        ;;
esac

printf '\0keep-selection\x1ftrue\n'

IFS='|' read -r w_state w_ssid w_signal <<< "$(get_wifi)"
IFS='|' read -r e_found e_dev e_state <<< "$(get_ethernet)"
IFS='|' read -r v_found v_name v_active <<< "$(get_vpn)"

# --- Wifi row ---
if [ "$w_state" = "off" ]; then
    wifi_text="${ICON_WIFI_OFF}  Wifi                         Off"
elif [ -z "$w_ssid" ]; then
    wifi_text="${ICON_WIFI_OFF}  Wifi                    Disconnected"
else
    if   (( w_signal >= 80 )); then wi=$ICON_WIFI_4
    elif (( w_signal >= 60 )); then wi=$ICON_WIFI_3
    elif (( w_signal >= 40 )); then wi=$ICON_WIFI_2
    elif (( w_signal >= 20 )); then wi=$ICON_WIFI_1
    else wi=$ICON_WIFI_0
    fi
    wifi_text=$(printf '%s  Wifi      %s  %s  %3d%%' "$wi" "$w_ssid" "$(render_bar "$w_signal")" "$w_signal")
fi

# --- Ethernet row ---
if [ "$e_found" != "found" ]; then
    eth_text="${ICON_ETHERNET}  Ethernet                   No device"
elif [ "$e_state" = "connected" ]; then
    eth_text="${ICON_ETHERNET}  Ethernet                  Connected"
else
    eth_text="${ICON_ETHERNET}  Ethernet                Disconnected"
fi

# --- VPN row ---
if [ "$v_found" != "found" ]; then
    vpn_text="${ICON_VPN_OFF}  VPN       Not configured"
elif [ "$v_active" = "1" ]; then
    vpn_text="${ICON_VPN_ON}  VPN       ${v_name}                 (on)"
else
    vpn_text="${ICON_VPN_OFF}  VPN       ${v_name}      (off)"
fi

printf '%s\0info\x1fwifi\n' "$wifi_text"
printf '%s\0info\x1fethernet\n' "$eth_text"
printf '%s\0info\x1fvpn\n' "$vpn_text"
printf '%s  Open Network Manager\0info\x1fmanager\n' "$ICON_MANAGER"
