#!/usr/bin/env bash
# Vicinae: Raycast-style command palette on Super+Space (Cmd+Space under keyd).
# Idempotent. Run from anywhere: ~/fedora-bootstrap/vicinae/install.sh
#
# Deliberate NON-choices (see README.md):
#   - no vicinae GNOME extension  -> Copyous keeps the clipboard, Tiling Shell keeps windows
#   - input_server off            -> keyd keeps the keyboard (no uinput injector)
#   - global_shortcuts.toggle ""  -> GNOME custom keybinding is the only hotkey source
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! rpm -q vicinae >/dev/null 2>&1; then
  sudo dnf -y copr enable quadratech188/vicinae
  sudo dnf -y install vicinae
fi

# Config. settings.json is the file vicinae reads (vicinae.json is IGNORED).
# The GUI rewrites settings.json, so hand-maintained bits live in scott.jsonc (imported).
mkdir -p "$HOME/.config/vicinae"
for f in settings.json scott.jsonc; do
  [[ -f "$HOME/.config/vicinae/$f" ]] || cp "$HERE/$f" "$HOME/.config/vicinae/$f"
done

# Super+Space: free it from input-source switching (single layout) and give it to Vicinae.
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['XF86Keyboard']"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift>XF86Keyboard']"
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/
dconf write "${P}name"    "'Vicinae'"
dconf write "${P}command" "'vicinae toggle'"
dconf write "${P}binding" "'<Super>space'"
CUR="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
if [[ "$CUR" != *"$P"* ]]; then
  if [[ "$CUR" == "@as []" ]]; then NEW="['$P']"; else NEW="${CUR%]}, '$P']"; fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
fi

gsettings set org.gnome.mutter center-new-windows true   # vicinae FAQ: GNOME Wayland centering
systemctl --user enable --now vicinae.service
sleep 2 && vicinae ping
echo ">>> Vicinae ready: Super+Space. Verify input server is off: pgrep -f vicinae-input-server (expect nothing)"
