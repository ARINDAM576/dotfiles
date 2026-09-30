#!/usr/bin/env python3
import json
import os
import select
import subprocess
import sys
import time

COLORS = [
    "#74c7ec", "#74c7ec", "#89b4fa", "#89b4fa",
    "#b4befe", "#b4befe", "#cba6f7", "#cba6f7",
    "#f5c2e7", "#f5c2e7", "#eba0ac", "#eba0ac"
]
GLYPHS = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

config_path = os.path.expanduser("~/.config/cava/cava.conf")

proc = subprocess.Popen(
    ["cava", "-p", config_path],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1
)

# 1.8-second grace period prevents toggling during speech pauses or quiet dynamics
GRACE_PERIOD = 1.8
last_audio_time = 0
is_visible = False
is_fading = False
last_rendered = ""

def get_flat_line(num_bars=12):
    return "".join(
        f"<span color='{COLORS[i % len(COLORS)]}'> </span>"
        for i in range(num_bars)
    )

try:
    while True:
        # Non-blocking check every 0.1s
        rlist, _, _ = select.select([proc.stdout], [], [], 0.1)
        now = time.time()

        if not rlist:
            # PipeWire paused/suspended stream
            if is_visible and not is_fading:
                if (now - last_audio_time) >= GRACE_PERIOD:
                    is_fading = True
                    fade_text = last_rendered if last_rendered else get_flat_line()
                    # 1. Trigger CSS opacity fade while locking exact text width
                    print(json.dumps({"text": fade_text, "class": "hidden"}), flush=True)
                    time.sleep(0.5)  # Wait for CSS transition
                    # 2. Collapse widget space after invisible
                    print(json.dumps({"text": "", "class": "hidden"}), flush=True)
                    is_visible = False
                    is_fading = False
            continue

        line = proc.stdout.readline()
        if not line:
            break

        raw_vals = [x for x in line.strip().split(";") if x.isdigit()]
        if not raw_vals:
            continue

        vals = [int(x) for x in raw_vals]

        if any(v > 0 for v in vals):
            # Active sound detected
            last_audio_time = now
            is_visible = True
            is_fading = False
            rendered = "".join(
                f"<span color='{COLORS[i % len(COLORS)]}'>{GLYPHS[min(v, 7)]}</span>"
                for i, v in enumerate(vals)
            )
            last_rendered = rendered
            print(json.dumps({"text": rendered, "class": "playing"}), flush=True)
        else:
            # Active stream, but all bars are zero (silence)
            if is_visible and not is_fading:
                if (now - last_audio_time) < GRACE_PERIOD:
                    # Hold flat baseline so pill maintains geometry
                    flat = get_flat_line(len(vals))
                    last_rendered = flat
                    print(json.dumps({"text": flat, "class": "playing"}), flush=True)
                else:
                    is_fading = True
                    fade_text = last_rendered if last_rendered else get_flat_line(len(vals))
                    print(json.dumps({"text": fade_text, "class": "hidden"}), flush=True)
                    time.sleep(0.5)
                    print(json.dumps({"text": "", "class": "hidden"}), flush=True)
                    is_visible = False
                    is_fading = False

except KeyboardInterrupt:
    pass
finally:
    proc.terminate()
