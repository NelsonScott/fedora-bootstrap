#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Fix Audio (reset Yeti mic)
# @vicinae.mode fullOutput
# @vicinae.icon 🎤
# @vicinae.keywords ["fix audio","fix mic","audio","mic","microphone","yeti","reset","replug","blue","zoom mic","no sound"]
# @vicinae.packageName Desktop
# The Blue Yeti sometimes hangs: PipeWire shows it RUNNING/unmuted but it delivers zero samples.
# Restarting PipeWire does nothing; only a USB unbind/bind (what a physical replug does) fixes it.
# Root part goes through pkexec, which Howdy answers with face auth (see /etc/pam.d/polkit-1).
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"
findsrc(){ pactl list sources short | awk '$2 ~ /Blue_Microphones.*analog-stereo$/ {print $2; exit}'; }
SRC=$(findsrc)
VOL=$( [[ -n $SRC ]] && pactl get-source-volume "$SRC" | grep -oE '[0-9]+%' | head -1 || echo 75% )
HELPER=/usr/local/bin/usb-replug; [[ -x $HELPER ]] || HELPER="$HOME/.local/bin/usb-replug"
pkexec "$HELPER" "Blue Microphones" || { echo "reset failed / auth cancelled"; exit 1; }
for i in $(seq 1 20); do sleep 1; SRC=$(findsrc); [[ -n $SRC ]] && break; done   # re-enumeration can take ~10s
[[ -n $SRC ]] || { echo "Yeti did not come back on PipeWire after 20s; try a physical replug"; exit 1; }
pactl set-default-source "$SRC"; pactl set-source-mute "$SRC" 0; pactl set-source-volume "$SRC" "$VOL"
echo "default mic -> Yeti (volume restored to $VOL). Running a 3s capture test (optionally say something)."
W="${XDG_RUNTIME_DIR:-/tmp}/yeti-test.wav"
timeout -s INT 3 pw-record --target "$SRC" --rate 16000 --channels 1 "$W" >/dev/null 2>&1
python3 - "$W" <<'PY'
import sys,wave,array
try:
    w=wave.open(sys.argv[1]); a=array.array('h',w.readframes(w.getnframes())); rate=w.getframerate()
except Exception as e:
    print(f"could not record from the Yeti at all ({e}); check it exists in Settings > Sound"); sys.exit(1)
secs=len(a)/rate; peak=max((abs(x) for x in a),default=0)
if secs<1: print("STILL HUNG: device present but delivered 0 seconds of audio. Physically replug the Yeti.")
elif peak<500: print(f"streaming OK ({secs:.1f}s) but silent (peak {peak}). Check the Yeti's physical mute button (red LED blinking = muted).")
else: print(f"Yeti is live: {secs:.1f}s recorded, peak {peak} (room noise alone reads ~1-2k; speech 5k+).")
PY
