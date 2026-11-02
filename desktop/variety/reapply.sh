#!/usr/bin/env bash
# Re-apply the custom Variety rendering after a `dnf update` replaces the
# variety package. Safe to re-run; only touches what is out of date, and only
# asks for sudo when a /usr/lib file actually needs restoring.
#
# Pieces:
#   1. QuoteWriter.py + UnsplashDownloader.py: whole-file copies into
#      /usr/lib (root). This script does that (asks for sudo only
#      when a file actually changed).
#   2. Display-size pin: NOT a Util.py copy any more (since 2026-10-25). It is
#      a user-level monkeypatch, pyoverride/sitecustomize.py, loaded through
#      PYTHONPATH in the autostart Exec. No root, survives dnf updates.
#   3. Autostart Exec: Variety rewrites ~/.config/autostart/variety.desktop on
#      every version bump, dropping GDK_BACKEND=x11 and the PYTHONPATH. This
#      script puts them back. gnome-session launches it (app-gnome-variety-*.scope),
#      not the generated systemd unit, so the env must live in the Exec line.
set -euo pipefail
P="$HOME/.config/variety/patches"
mod_file(){ python3 -c "import $1, sys; print(sys.modules['$1'].__file__)"; }
put(){ # $1 = patched source, $2 = module
  local dst; dst=$(mod_file "$2")
  if cmp -s "$1" "$dst"; then echo "ok        $dst"
  else sudo cp "$1" "$dst"; echo "restored  $dst"; fi
}
put "$P/QuoteWriter.patched.py"        variety.QuoteWriter
put "$P/UnsplashDownloader.patched.py" variety.plugins.builtin.downloaders.UnsplashDownloader

EXEC="Exec=/bin/bash -c \"sleep 20 \\&\\& GDK_BACKEND=x11 PYTHONPATH=$HOME/.config/variety/patches/pyoverride /usr/bin/variety --profile $HOME/.config/variety/\""
AS="$HOME/.config/autostart/variety.desktop"
if [ -f "$AS" ] && ! grep -q "pyoverride" "$AS"; then
  sed -i "s|^Exec=.*|$EXEC|" "$AS"
  echo "restored GDK_BACKEND=x11 + PYTHONPATH pin in $AS"
fi

# Self-check: what Variety will see when launched from the autostart entry.
SIZE=$(cd /tmp && GDK_BACKEND=x11 PYTHONPATH="$P/pyoverride" python3 -sP -c \
  "from variety.Util import Util; print('%dx%d' % Util.get_primary_display_size())")
echo "display size Variety will use: $SIZE (want $(cat "$HOME/.config/variety/screen_size"))"
echo "A running Variety keeps the OLD code/env. Restart it (2 visible wallpaper flips):"
echo "  variety --quit; sleep 3; setsid -f env GDK_BACKEND=x11 PYTHONPATH=$P/pyoverride /usr/bin/variety --profile $HOME/.config/variety/ >/dev/null 2>&1"
