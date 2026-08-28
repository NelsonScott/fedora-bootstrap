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

# --- Script commands (hide windows, corners, screenshot, record, usage, wallpaper) ---
mkdir -p "$HOME/.local/share/vicinae"
ln -sfn "$HERE/scripts" "$HOME/.local/share/vicinae/scripts"
gsettings set org.gnome.desktop.wm.keybindings show-desktop "['<Control><Super><Alt>h']"   # hide-windows.sh sends this via ydotool
# Window tiling for the corner/half scripts: our own tiny D-Bus extension (layout-independent,
# unlike driving Tiling Shell's move-window keys). Needs ONE logout/login to load.
ln -sfn "$HERE/desktop-actions@scottnelson" "$HOME/.local/share/gnome-shell/extensions/desktop-actions@scottnelson"
CUR="$(gsettings get org.gnome.shell enabled-extensions)"
[[ "$CUR" == *desktop-actions@scottnelson* ]] || gsettings set org.gnome.shell enabled-extensions "${CUR%]}, 'desktop-actions@scottnelson']"
systemctl --user restart vicinae
echo ">>> Log out/in once so desktop-actions@scottnelson loads (corner/half commands depend on it)."
