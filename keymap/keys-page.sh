#!/usr/bin/env bash
# Cmd+/ : keybindings page, regenerated live on every press. Cmd+/ again or Esc closes it.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
mkdir -p "$HOME/.cache/keymap"
python3 "$HOME/fedora-bootstrap/keymap/keymap.py" --format html > "$HOME/.cache/keymap/keymap.html"
W="$HOME/fedora-bootstrap/keymap/keys-window.py"; U="file://$HOME/.cache/keymap/keymap.html"
# GL first (smooth scrolling). GTK4's GL renderer dies instantly with "Error 71 (Protocol error)
# dispatching to Wayland display" whenever NVIDIA userspace and kernel module versions differ
# (any mid-upgrade window), so if it exits within 4s for any reason other than a toggle-close
# (exit 3), relaunch on the cairo software renderer.
t0=$(date +%s); GSK_RENDERER=gl python3 "$W" "$U" >/dev/null 2>&1; rc=$?
if [[ $rc -ne 0 && $rc -ne 3 && $(( $(date +%s) - t0 )) -lt 4 ]]; then
  rm -f "$HOME/.cache/keymap/window.pid"
  GSK_RENDERER=cairo WEBKIT_DISABLE_DMABUF_RENDERER=1 WEBKIT_DISABLE_COMPOSITING_MODE=1 exec python3 "$W" "$U" >/dev/null 2>&1
fi
