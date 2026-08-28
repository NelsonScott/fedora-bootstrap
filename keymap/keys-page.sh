#!/usr/bin/env bash
# Cmd+/ : full-screen keybindings page (regenerated live on every press).
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
mkdir -p "$HOME/.cache/keymap"
python3 "$HOME/fedora-bootstrap/keymap/keymap.py" --format html > "$HOME/.cache/keymap/keymap.html"
exec google-chrome --app="file://$HOME/.cache/keymap/keymap.html" --start-maximized --user-data-dir="$HOME/.cache/keymap/chrome-profile" --no-first-run --disable-features=Translate --class=keymap >/dev/null 2>&1
