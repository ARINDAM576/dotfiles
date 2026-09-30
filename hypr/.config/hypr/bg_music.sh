#!/bin/bash

# --- CONFIGURATION ---
FADE_STEPS=11      # How many steps to fade down/up (higher = smoother but slower)
FADE_DELAY=0.08    # Time in seconds between each step (e.g., 0.03 * 10 steps = 0.3s total fade)
MAX_VOL="1.0"      # Your normal listening volume (max 1.0)
MIN_VOL="0.0"      # Target fade-out volume
# ---------------------

# Track the state to avoid firing loops repeatedly
CURRENT_STATE="playing"

fade_out() {
    # Gradually lower volume
    for i in $(seq 1 $FADE_STEPS); do
        # Calculate current volume step using 'bc' for floating-point math
        CUR_VOL=$(echo "$MAX_VOL - (($MAX_VOL - $MIN_VOL) * $i / $FADE_STEPS)" | bc -l)
        playerctl -p spotify volume "$CUR_VOL" 2>/dev/null
        sleep $FADE_DELAY
    done
    # Finally pause and reset volume back to max so it's ready for next time
    playerctl -p spotify pause 2>/dev/null
    playerctl -p spotify volume "$MAX_VOL" 2>/dev/null
}

fade_in() {
    # Start playing at minimum volume
    playerctl -p spotify volume "$MIN_VOL" 2>/dev/null
    playerctl -p spotify play 2>/dev/null
    
    # Gradually raise volume
    for i in $(seq 1 $FADE_STEPS); do
        CUR_VOL=$(echo "$MIN_VOL + (($MAX_VOL - $MIN_VOL) * $i / $FADE_STEPS)" | bc -l)
        playerctl -p spotify volume "$CUR_VOL" 2>/dev/null
        sleep $FADE_DELAY
    done
}

while true; do
    # Find any active media players that are NOT Spotify
    OTHER_PLAYERS=$(playerctl -l 2>/dev/null | grep -v "spotify")
    MEDIA_PLAYING=false

    for player in $OTHER_PLAYERS; do
        if [ "$(playerctl -p "$player" status 2>/dev/null)" = "Playing" ]; then
            MEDIA_PLAYING=true
            break
        fi
    done

    SPOTIFY_STATUS=$(playerctl -p spotify status 2>/dev/null)

    if [ "$MEDIA_PLAYING" = true ]; then
        # If media started and Spotify is playing, fade out and pause
        if [ "$SPOTIFY_STATUS" = "Playing" ] && [ "$CURRENT_STATE" = "playing" ]; then
            CURRENT_STATE="paused_by_script"
            fade_out
        fi
    else
        # If media stopped and the script was the one that paused Spotify, fade it back in
        if [ "$SPOTIFY_STATUS" = "Paused" ] && [ "$CURRENT_STATE" = "paused_by_script" ]; then
            CURRENT_STATE="playing"
            fade_in
        fi
        
        # Reset state if you manually messed with Spotify playback
        if [ "$SPOTIFY_STATUS" = "Playing" ]; then
            CURRENT_STATE="playing"
        fi
    fi

    # Fast polling rate (0.2s) ensures it catches browser videos instantly
    sleep 0.1
done
