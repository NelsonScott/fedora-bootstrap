#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Check for Updates Now
# @vicinae.mode silent
# @vicinae.icon 🔄
# @vicinae.keywords ["updates","check updates","update now","look now","software updates","refresh updates","dnf","upgrade"]
# @vicinae.packageName System
# Forces PackageKit (what GNOME Software's badge reads) to re-scan, then reports the real count.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
pkcon refresh force >/dev/null 2>&1
n=$(pkcon get-updates 2>/dev/null | grep -cE "^(Security|Bug fix|Enhancement|Normal|Important|Critical|Low)")
f=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
if [ "$n" = 0 ] && [ "$f" = 0 ]; then
  notify-send -i software-update-available "Updates" "Fresh scan: nothing pending (rpm 0, flatpak 0)."
else
  notify-send -i software-update-available "Updates" "Fresh scan: $n rpm, $f flatpak pending. Opening Software…"
  gnome-software --mode updates >/dev/null 2>&1 &
fi
