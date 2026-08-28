#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Clipboard History (Copyous)
# @vicinae.mode silent
# @vicinae.icon 📋
# @vicinae.keywords ["copyous","clipboard","clip","copy","paste","history","maccy"]
# @vicinae.packageName Desktop
# Copyous is a GNOME Shell extension (no .desktop file), so Vicinae can't list it
# as an app. It exports a D-Bus Toggle; same as Super+Shift+C.
sleep 0.25   # let the Vicinae window close so the popup lands on the previous window
gdbus call --session --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Copyous \
  --method org.gnome.Shell.Extensions.Copyous.Show >/dev/null
