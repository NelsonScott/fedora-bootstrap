#!/bin/bash
# runs inside dbus-run-session: nested shell, wait, open menu, snapshot
OUT=$1
gnome-shell --headless --wayland --no-x11 --virtual-monitor 1280x720 > "$OUT/shell.log" 2>&1 &
SH=$!
for i in $(seq 1 30); do sleep 1; grep -q "claude-usage\] enable" "$OUT/shell.log" && break; done
sleep 4
gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/ClaudeUsage --method org.scottnelson.ClaudeUsage.OpenMenu
sleep 3
gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/ClaudeUsage --method org.scottnelson.ClaudeUsage.Snap "$OUT/menu.png"
sleep 3
kill $SH; wait $SH 2>/dev/null
