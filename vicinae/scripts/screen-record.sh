#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Record Screen (start / stop)
# @vicinae.mode silent
# @vicinae.icon 🎥
# @vicinae.keywords ["record","recording","screen record","video","capture video","rec","stop recording","screencast"]
# @vicinae.packageName Desktop
# Toggles GNOME's built-in screencast via D-Bus (the Ctrl+Shift+Alt+R chord is unreliable under injection).
# Output: ~/Videos/Screencasts/Screencast-<date>.webm
STATE="$XDG_RUNTIME_DIR/vicinae-screencast.active"
DEST="$HOME/Videos/Screencasts"; mkdir -p "$DEST"
BUS=(gdbus call --session --dest org.gnome.Shell.Screencast --object-path /org/gnome/Shell/Screencast)
if [[ -f "$STATE" ]]; then
  "${BUS[@]}" --method org.gnome.Shell.Screencast.StopScreencast >/dev/null; rm -f "$STATE"
  notify-send -i media-record "Recording saved" "$(ls -t "$DEST" | head -1)"
else
  sleep 0.3  # let the Vicinae window close so it isn't in the recording
  OUT=$("${BUS[@]}" --method org.gnome.Shell.Screencast.Screencast "$DEST/Screencast-%d-%t.webm" '{}')
  [[ "$OUT" == "(true,"* ]] && touch "$STATE" && notify-send -i media-record "Recording started" "Run 'Record Screen' again to stop"
fi
