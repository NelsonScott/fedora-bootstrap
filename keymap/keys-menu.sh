#!/usr/bin/env bash
# Super+K: searchable list of every keybinding on this PC (Omarchy-style).
# Enter copies the selected line to the clipboard.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
sel=$(python3 "$HOME/fedora-bootstrap/keymap/keymap.py" --format dmenu \
      | vicinae dmenu -n "Keybindings" -s "{count} bindings" -p "Search chord, action, or Ctrl+… target" -W 1100 -H 700 --no-quick-look)
[[ -n "$sel" ]] && { printf '%s' "$sel" | wl-copy; notify-send -t 2000 "Copied" "$sel"; }
