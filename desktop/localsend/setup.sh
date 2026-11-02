#!/usr/bin/env bash
# LocalSend on the PC as a background drop target for iPhone screenshots (Nov 2 2026).
# Files land in /tmp/localsend (gone at reboot, folder recreated at login); the app lives in the
# top-bar tray (needs the AppIndicator extension) and starts hidden at login. Port 53317 is LocalSend's.
set -euo pipefail
cd "$(dirname "$0")"
flatpak install -y --user --noninteractive flathub org.localsend.localsend_app
flatpak override --user --filesystem=/tmp/localsend org.localsend.localsend_app
install -Dm644 localsend.desktop ~/.config/autostart/localsend.desktop
install -Dm644 localsend-tmpfiles.conf ~/.config/user-tmpfiles.d/localsend.conf
systemd-tmpfiles --user --create localsend.conf
sudo firewall-cmd --permanent --add-port=53317/tcp --add-port=53317/udp && sudo firewall-cmd --reload
# In the app once: Settings > Minimize to tray = on, Receive > Quick Save = on, name it "fedora".
# (shared_preferences.json: ls_minimize_to_tray is a bool, ls_quick_save is a STRING enum, do not hand-edit the latter.)
flatpak run --user org.localsend.localsend_app --hidden &
