#!/usr/bin/env bash
# Keybindings page on Cmd+/ (Super+slash). Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/keymap/
dconf write "${P}name"    "'Keybindings page (Cmd+/)'"
dconf write "${P}command" "'$HERE/keys-page.sh'"
dconf write "${P}binding" "'<Super>slash'"
python3 - <<PY
import subprocess,ast
cur=subprocess.run(["gsettings","get","org.gnome.settings-daemon.plugins.media-keys","custom-keybindings"],capture_output=True,text=True).stdout.strip()
lst=ast.literal_eval(cur.replace("@as ","")) if cur else []
if "$P" not in lst: lst.append("$P")
subprocess.run(["gsettings","set","org.gnome.settings-daemon.plugins.media-keys","custom-keybindings",str(lst)])
PY
echo "Cmd+/ -> $HERE/keys-page.sh"
