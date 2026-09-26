#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Glance Dashboard
# @vicinae.mode silent
# @vicinae.icon 📊
# @vicinae.keywords ["glance","dashboard","screensaver","show dashboard","feeds"]
# @vicinae.packageName Desktop
# Toggle: opens the Glance dashboard fullscreen (same page as glance-idle.service); Esc, Alt+F4, or run again to close.
# Own Chrome profile so it never collides with the idle screensaver's (~/.cache/glance-idle-chrome) or Scott's main one.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
URL="http://localhost:8090/?kiosk=1"   # ?kiosk=1 turns on Esc-to-close in live.js
PROFILE="$HOME/.cache/glance-manual-chrome"
# Vicinae kills a silent script ~10s after launch, so never exec a GUI app: detach it.
launch(){ setsid -f "$@" >/dev/null 2>&1; }

if pgrep -f -- "--user-data-dir=$PROFILE" >/dev/null; then
    pkill -o -f -- "--user-data-dir=$PROFILE"   # oldest = the browser process; renderers follow
    exit 0
fi
if ! curl -s -o /dev/null --max-time 3 "$URL"; then
    systemctl --user start glance-feed.service
    for _ in 1 2 3 4 5 6; do curl -s -o /dev/null --max-time 2 "$URL" && break; sleep 1; done
fi
[[ -n "$GLANCE_DRY_RUN" ]] && { echo "would launch: $URL"; exit 0; }
launch /usr/bin/google-chrome --user-data-dir="$PROFILE" --kiosk --no-first-run \
    --no-default-browser-check --disable-session-crashed-bubble --disable-infobars --app="$URL"
