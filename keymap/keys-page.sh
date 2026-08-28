#!/usr/bin/env bash
# Cmd+/ : keybindings page, regenerated live on every press. Press Cmd+/ again or Esc to close.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
mkdir -p "$HOME/.cache/keymap"
python3 "$HOME/fedora-bootstrap/keymap/keymap.py" --format html > "$HOME/.cache/keymap/keymap.html"
# cairo renderer: static page, and GTK4 GL breaks whenever NVIDIA userspace and kernel module versions differ (mid-upgrade).
export GSK_RENDERER=cairo WEBKIT_DISABLE_DMABUF_RENDERER=1 WEBKIT_DISABLE_COMPOSITING_MODE=1
exec python3 "$HOME/fedora-bootstrap/keymap/keys-window.py" "file://$HOME/.cache/keymap/keymap.html" >/dev/null 2>&1
