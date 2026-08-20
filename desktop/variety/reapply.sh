#!/usr/bin/env bash
# Re-apply the custom QuoteWriter after a `dnf update` replaces the variety package.
# The stock upstream file is kept alongside this script as QuoteWriter.py.orig.
set -euo pipefail
SRC="$HOME/.config/variety/patches/QuoteWriter.patched.py"
DST=$(python3 -c "import variety.QuoteWriter as m; print(m.__file__)")
sudo cp "$SRC" "$DST"
UP="$HOME/.config/variety/patches/UnsplashDownloader.patched.py"
UDST=$(python3 -c "import variety.plugins.builtin.downloaders.UnsplashDownloader as m; print(m.__file__)")
[ -f "$UP" ] && sudo cp "$UP" "$UDST" && echo "re-applied $UDST"
echo "re-applied to $DST"
UT="$HOME/.config/variety/patches/Util.patched.py"
UTDST=$(python3 -c "import variety.Util as m; print(m.__file__)")
[ -f "$UT" ] && sudo cp "$UT" "$UTDST" && echo "re-applied $UTDST"
