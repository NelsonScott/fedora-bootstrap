#!/usr/bin/env bash
# desktop/install.sh — Mac-like GNOME 50 desktop restyle (Aug 2026).
#
# What this sets up (all user-scoped unless noted):
#   - GNOME shell extensions: Kiwi (+ Kiwi Menu), Rounded Window Corners
#     Reborn, Rounded Corners (screen), Just Perfection (dnf)
#   - macOS cursor (ful1e5/apple_cursor) + WhiteSur icon theme
#   - gsettings: window buttons right, cursor size 48, dock icon size 84
#   - Qt dark theming (qt6ct + Kvantum KvArcDark) so Qt apps (CopyQ etc.)
#     stop rendering as unthemed Windows-95 widgets
#   - Variety wallpaper rig: rotating 4K sources, styled quote overlay,
#     ticking styled clock (see variety/ and its patches)
#
# ############################################################################
# ##  WARNING — DO NOT INSTALL "Blur my Shell" (as of Aug 2026).            ##
# ##  v72 + GNOME 50.2 Wayland + NVIDIA has a confirmed OOM leak:           ##
# ##  gnome-shell grows to 16-25 GB RSS and the OOM killer takes the whole  ##
# ##  session. Fix is merged upstream but unreleased. Re-check before use:  ##
# ##  https://github.com/aunetx/blur-my-shell/issues/957                    ##
# ############################################################################
#
# Also deliberately NOT here:
#   - Full GTK themes (WhiteSur/Orchis/...): only ~2 GTK3 apps remain on this
#     machine, and their GNOME Shell CSS is stuck at GNOME 48 — breaks on 50.
#   - Display scaling / monitor layout: hardware-specific. On the 4K Samsung
#     (DP-4) we run 125% fractional scaling with the portrait 1080p at
#     x=3072 — set via Settings > Displays on a new machine.
#   - Phase 3 (Marble shell theme + custom palette): not yet decided.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">>> desktop: packages"
sudo dnf install -y variety ImageMagick qt6ct kvantum python3-fonttools \
  gnome-shell-extension-just-perfection

# ---------------------------------------------------------------------------
# Fonts for the wallpaper overlay (Space Grotesk, Cormorant Garamond,
# IBM Plex Mono). ImageMagick cannot pick a weight out of a VARIABLE font
# (it silently renders the thin default master), so static instances are cut
# with fontTools at the exact design weights.
# ---------------------------------------------------------------------------
FD="$HOME/.local/share/fonts/design"
if [[ ! -f "$FD/CormorantGaramond-MediumItalic.ttf" ]]; then
  echo ">>> desktop: overlay fonts"
  mkdir -p "$FD" && cd "$FD"
  B=https://github.com/google/fonts/raw/main/ofl
  curl -sfL -o "SpaceGrotesk[wght].ttf"              "$B/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf"
  curl -sfL -o "CormorantGaramond[wght].ttf"         "$B/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf"
  curl -sfL -o "CormorantGaramond-Italic[wght].ttf"  "$B/cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf"
  curl -sfL -o "IBMPlexMono-Regular.ttf"             "$B/ibmplexmono/IBMPlexMono-Regular.ttf"
  python3 -m fontTools.varLib.instancer "CormorantGaramond[wght].ttf"        wght=500 -o CormorantGaramond-Medium.ttf
  python3 -m fontTools.varLib.instancer "CormorantGaramond[wght].ttf"        wght=400 -o CormorantGaramond-Regular.ttf
  python3 -m fontTools.varLib.instancer "CormorantGaramond-Italic[wght].ttf" wght=500 -o CormorantGaramond-MediumItalic.ttf
  python3 -m fontTools.varLib.instancer "SpaceGrotesk[wght].ttf"             wght=300 -o SpaceGrotesk-Light.ttf
  python3 -m fontTools.varLib.instancer "SpaceGrotesk[wght].ttf"             wght=400 -o SpaceGrotesk-Regular.ttf
  fc-cache -f "$HOME/.local/share/fonts"
  cd - >/dev/null
fi

# ---------------------------------------------------------------------------
# Cursor + icons
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.local/share/icons"
if [[ ! -d "$HOME/.local/share/icons/macOS" ]]; then
  echo ">>> desktop: macOS cursor theme"
  curl -sfL -o /tmp/macOS.tar.xz \
    https://github.com/ful1e5/apple_cursor/releases/latest/download/macOS.tar.xz
  tar -xf /tmp/macOS.tar.xz -C "$HOME/.local/share/icons"
fi
if [[ ! -d "$HOME/.local/share/icons/WhiteSur-dark" ]]; then
  echo ">>> desktop: WhiteSur icons"
  git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icon-theme
  /tmp/WhiteSur-icon-theme/install.sh -d "$HOME/.local/share/icons"
  rm -rf /tmp/WhiteSur-icon-theme
fi

# ---------------------------------------------------------------------------
# GNOME settings. Wayland does NOT scale cursors, so 24px is tiny at 4K.
# ---------------------------------------------------------------------------
echo ">>> desktop: gsettings"
gsettings set org.gnome.desktop.wm.preferences button-layout 'minimize,maximize,close:appmenu'
gsettings set org.gnome.desktop.interface cursor-size 48
gsettings set org.gnome.desktop.interface cursor-theme 'macOS'
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
if gsettings list-schemas | grep -q dash-to-dock; then
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 84
fi

# ---------------------------------------------------------------------------
# Qt theming: qt6ct + Kvantum (KvArcDark). environment.d makes every future
# Qt app pick it up. GOTCHA: if this account has lingering user services
# (loginctl show-user -p Linger), the systemd user manager never restarts on
# re-login and environment.d changes DON'T apply — inject manually once:
#   systemctl --user set-environment QT_QPA_PLATFORMTHEME=qt6ct
# ---------------------------------------------------------------------------
echo ">>> desktop: Qt theming"
install -Dm644 "$DIR/config/qt6ct.conf"       "$HOME/.config/qt6ct/qt6ct.conf"
install -Dm644 "$DIR/config/kvantum.kvconfig" "$HOME/.config/Kvantum/kvantum.kvconfig"
install -Dm644 "$DIR/config/environment.d/50-qt-theme.conf" "$HOME/.config/environment.d/50-qt-theme.conf"
install -Dm644 "$DIR/config/environment.d/50-cursor.conf"   "$HOME/.config/environment.d/50-cursor.conf"

# ---------------------------------------------------------------------------
# Shell extensions from extensions.gnome.org (Just Perfection came via dnf).
# Freshly installed extensions load at the NEXT login on Wayland.
# ---------------------------------------------------------------------------
GVER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
for UUID in kiwi@kemma kiwimenu@kemma rounded-window-corners@fxgn Rounded_Corners@lennart-k; do
  if ! gnome-extensions info "$UUID" &>/dev/null; then
    echo ">>> desktop: installing extension $UUID"
    INFO=$(curl -sfL "https://extensions.gnome.org/extension-info/?uuid=$UUID&shell_version=$GVER")
    DL=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['download_url'])" "$INFO")
    curl -sfL -o "/tmp/$UUID.zip" "https://extensions.gnome.org$DL"
    gnome-extensions install --force "/tmp/$UUID.zip"
  fi
  gnome-extensions enable "$UUID" || true
done
gnome-extensions enable just-perfection-desktop@just-perfection || true

# ---------------------------------------------------------------------------
# Variety: rotating 4K wallpapers with a styled quote + ticking styled clock.
#
# Three upstream bugs are patched locally (reapply.sh re-installs the patches;
# RUN IT AGAIN after any `dnf update` that touches variety):
#   1. QuoteWriter.py — replaced quote renderer: three designs (a/b/c) drawn
#      with Cairo/Pango/PIL instead of the stock hard-edged rectangle.
#   2. Util.py — get_primary_display_size() honors ~/.config/variety/screen_size,
#      because GDK misdetects the monitor on Wayland AND under fractional
#      scaling (https://github.com/varietywalls/variety/issues/863).
#   3. UnsplashDownloader.py — raise fetch floor 1980 -> 3840 so a misdetected
#      screen can never lock downloads at sub-4K.
# Related upstream: negative clock offsets bug
#   https://github.com/varietywalls/variety/issues/862 (PR #864).
# ---------------------------------------------------------------------------
echo ">>> desktop: Variety"
install -Dm755 "$DIR/variety/variety-style" "$HOME/.local/bin/variety-style"
mkdir -p "$HOME/.config/variety/patches"
cp "$DIR/variety/"*.patched.py "$DIR/variety/reapply.sh" "$HOME/.config/variety/patches/"
chmod +x "$HOME/.config/variety/patches/reapply.sh"
"$HOME/.config/variety/patches/reapply.sh"

# HARDWARE-SPECIFIC: pin the real panel resolution (see Util patch above).
# Adjust for a different primary monitor.
[[ -f "$HOME/.config/variety/screen_size" ]] || echo "3840x2160" > "$HOME/.config/variety/screen_size"
[[ -f "$HOME/.config/variety/quote_style" ]] || echo "b" > "$HOME/.config/variety/quote_style"

# Autostart with GDK_BACKEND=x11 (native-Wayland GDK misdetects the display).
install -Dm644 "$DIR/config/variety-autostart.desktop" "$HOME/.config/autostart/variety.desktop"

# Tune sources on an existing config (first run of variety creates it):
#   keep Bing UHD + Unsplash (patched to >=4K), disable the sub-4K sources
#   (Earth View maxes at 1800px; APOD is a mixed bag), rotate every 2h,
#   only show images >= 80% of screen size.
CONF="$HOME/.config/variety/variety.conf"
if [[ -f "$CONF" ]]; then
  sed -i -E \
    -e 's/^change_interval = .*/change_interval = 7200/' \
    -e 's/^min_size_enabled = .*/min_size_enabled = True/' \
    -e 's/^(src[0-9]+ = )True(\|(apod|earthview)\|)/\1False\2/' \
    -e 's/^(src[0-9]+ = )True(\|folder\|\/usr\/share\/backgrounds)/\1False\2/' \
    "$CONF"
  if ! grep -q '^wallhaven_api_key = .\+' "$CONF" 2>/dev/null; then
    echo ">>> desktop: NOTE — add your Wallhaven API key to variety.conf"
    echo ">>>   (wallhaven.cc/settings/account; key goes in wallhaven_api_key=,"
    echo ">>>    then add a 4K toplist search as a wallhaven source)"
  fi
else
  echo ">>> desktop: NOTE — run variety once, then re-run this script to tune its sources"
fi

echo ">>> desktop: done. Log out/in to load freshly installed extensions."
echo ">>> desktop: switch wallpaper overlay styles with: variety-style {a|b|c} [top]"
