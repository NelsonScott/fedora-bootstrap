#!/bin/bash
# Reproduces the LIVE sequence: data applied while the menu is closed, then the menu is opened
# with no refresh (snap1); then closed, refreshed while closed, reopened (snap2).
OUT=$1; D="--session --dest org.gnome.Shell --object-path /org/scottnelson/ClaudeUsage"
gnome-shell --headless --wayland --no-x11 --virtual-monitor 1280x720 > "$OUT/shell.log" 2>&1 &
SH=$!
for i in $(seq 1 30); do sleep 1; grep -q "claude-usage\] enable" "$OUT/shell.log" && break; done
sleep 4
gdbus call $D --method org.scottnelson.ClaudeUsage.OpenMenuRaw; sleep 3
gdbus call $D --method org.scottnelson.ClaudeUsage.Snap "$OUT/1-open-no-refresh.png"; sleep 3
gdbus call $D --method org.scottnelson.ClaudeUsage.CloseMenu; sleep 2
gdbus call $D --method org.scottnelson.ClaudeUsage.Refresh; sleep 2
gdbus call $D --method org.scottnelson.ClaudeUsage.OpenMenuRaw; sleep 3
gdbus call $D --method org.scottnelson.ClaudeUsage.Snap "$OUT/2-refreshed-closed-then-open.png"; sleep 3
kill $SH; wait $SH 2>/dev/null
