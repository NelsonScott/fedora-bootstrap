# Shared helper: tile the focused window via the desktop-actions@scottnelson GNOME extension.
tile() {  # tile x y w h   (fractions of the monitor work area)
  sleep 0.25   # let the Vicinae window close so the previous window is focused again
  local out
  if ! out=$(gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/DesktopActions \
        --method org.scottnelson.DesktopActions.Tile "$1" "$2" "$3" "$4" 2>&1); then
    notify-send -i dialog-warning "Window tiling unavailable" "desktop-actions@scottnelson extension not loaded. Log out and back in once (gnome-extensions enable desktop-actions@scottnelson)."
    exit 1
  fi
}
