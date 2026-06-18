#!/usr/bin/env bash
#
# fedora-bootstrap — personal Fedora 44 Workstation setup
# Target hardware: Ryzen 9 9950X + RTX 5090 (Blackwell)
#
# Idempotent: safe to re-run. Each step checks before it changes anything.
# `set -x` is on so you can watch every command as it runs.
#
# Usage:
#   git clone https://github.com/nelsonscott/fedora-bootstrap
#   cd fedora-bootstrap
#   ./bootstrap.sh
#
# Do NOT run this whole script with sudo. It calls sudo only where needed,
# so it can still install oh-my-zsh and chsh for your own user.

set -euo pipefail
set -x

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNF_LIST="$REPO_DIR/packages/dnf.txt"
FLATPAK_LIST="$REPO_DIR/packages/flatpak.txt"

# Read a package list file: strip comments and blank lines, return one per line.
read_pkg_list() {
  # shellcheck disable=SC2002
  grep -vE '^\s*(#|$)' "$1" | sed 's/#.*//' | awk '{$1=$1};1' | grep -v '^$'
}

# Print a clean, visible banner before each major step. Toggling xtrace off/on
# inside braces (with stderr hushed) keeps the banner from being preceded by a
# noisy `+ echo ...` trace line — while every real command still runs under
# `set -x`. So you get both: readable section headers AND full command tracing.
step() {
  { set +x; } 2>/dev/null
  echo
  echo "============================================================"
  echo "==> $*"
  echo "============================================================"
  { set -x; } 2>/dev/null
}

# ---------------------------------------------------------------------------
# 1. System upgrade
# ---------------------------------------------------------------------------
step "Step 1/10  System upgrade (dnf upgrade -y)"
sudo dnf upgrade -y

# ---------------------------------------------------------------------------
# 2. RPM Fusion (free + nonfree) — needed for NVIDIA drivers, codecs, Steam...
#    Idempotent: dnf install of an already-installed release rpm is a no-op.
# ---------------------------------------------------------------------------
step "Step 2/10  Enable RPM Fusion (free + nonfree)"
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Refresh metadata so the new repos are usable in this same run.
sudo dnf upgrade --refresh -y

# ---------------------------------------------------------------------------
# 3. NVIDIA driver for the RTX 5090 (Blackwell / GB202)
#
#    The RTX 5090 needs the NVIDIA 570+ driver branch. RPM Fusion's
#    `akmod-nvidia` tracks the latest production branch (570/580+), which
#    supports Blackwell — so the standard RPM Fusion package set is correct.
#    There is NO separate "blackwell" package: akmod-nvidia IS the right one.
#
#      akmod-nvidia              -> kernel module, auto-rebuilt on kernel updates
#      xorg-x11-drv-nvidia-cuda  -> CUDA libraries + nvidia-smi
#
#    !!! REBOOT REQUIRED after this step. The akmod has to compile against
#    !!! your running kernel first (can take a few minutes — watch with
#    !!! `modinfo -F version nvidia` until it prints a version, then reboot).
#
#    Secure Boot note: if Secure Boot is enabled, unsigned akmods won't load.
#    Either disable Secure Boot in BIOS, or enroll the akmods key (see
#    `sudo akmods --force` + `mokutil`). Easiest on a fresh box: disable it.
# ---------------------------------------------------------------------------
step "Step 3/10  NVIDIA driver for RTX 5090 (akmod-nvidia + CUDA) — REBOOT after!"
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
# Kick off the module build now so it's ready by the time you reboot.
sudo akmods --force || true

# ---------------------------------------------------------------------------
# 4. DNF packages (from packages/dnf.txt)
# ---------------------------------------------------------------------------
step "Step 4/10  Install DNF packages from packages/dnf.txt"
if [[ -f "$DNF_LIST" ]]; then
  # One `dnf install` call with the whole list: idempotent and fast.
  # shellcheck disable=SC2046
  sudo dnf install -y $(read_pkg_list "$DNF_LIST")
fi

# Full ffmpeg from RPM Fusion: Fedora preinstalls a stripped `ffmpeg-free` that
# *conflicts* with it, so swap (don't install) — and only if not already done.
if rpm -q ffmpeg-free >/dev/null 2>&1; then
  sudo dnf swap -y ffmpeg-free ffmpeg
fi

# 1Password desktop — not in Fedora/Flathub, so add 1Password's signed vendor
# repo and install it. Idempotent: skipped once the package is present.
if ! rpm -q 1password >/dev/null 2>&1; then
  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'REPO'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPO
  sudo dnf install -y 1password
fi

# ---------------------------------------------------------------------------
# 5. Flatpak apps (from packages/flatpak.txt)
# ---------------------------------------------------------------------------
step "Step 5/10  Set up Flathub + install Flatpak apps from packages/flatpak.txt"
sudo dnf install -y flatpak
# Add Flathub if it isn't there yet (idempotent: --if-not-exists).
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo

if [[ -f "$FLATPAK_LIST" ]]; then
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    flatpak install -y --noninteractive flathub "$app"
  done < <(read_pkg_list "$FLATPAK_LIST")
fi

# ---------------------------------------------------------------------------
# 6. Node.js (for Claude Code) + npm
# ---------------------------------------------------------------------------
step "Step 6/10  Install Node.js + npm (for Claude Code)"
sudo dnf install -y nodejs npm

set +x
echo
echo ">>> Node installed: $(node --version), npm $(npm --version)"
echo ">>> To install Claude Code, run (after a relogin so PATH is set):"
echo
echo "      sudo npm install -g @anthropic-ai/claude-code"
echo
echo "    (or, to avoid sudo, set an npm prefix in \$HOME and use:"
echo "      npm install -g @anthropic-ai/claude-code )"
echo
set -x

# ---------------------------------------------------------------------------
# 7. keyd — Mac-style Cmd key (swap Super<->Alt + Cmd shortcuts)
#
#    Goal: make the key right next to the spacebar behave like a Mac's Cmd.
#    On a PC keyboard the thumb key next to space is Alt and Super(Win) sits
#    one slot left; on a Mac that thumb key is Cmd. So we swap Super<->Alt to
#    recreate the Mac bottom row, then map Super+C/V/X to Copy/Paste/Cut and
#    Super+T to a new terminal tab. Tapping Super alone still opens Activities.
#
#    keyd is a system-level remapper that works on both X11 and Wayland and is
#    unaffected by the desktop. It is NOT in Fedora's repos, so we enable the
#    alternateved/keyd COPR first. Config lives in keyd/default.conf in this
#    repo (version-controlled) and is copied into place below.
# ---------------------------------------------------------------------------
step "Step 7/10  Install + configure keyd (Mac-style Cmd key)"
sudo dnf copr enable -y alternateved/keyd
sudo dnf install -y keyd

sudo mkdir -p /etc/keyd
sudo cp "$REPO_DIR/keyd/default.conf" /etc/keyd/default.conf

# Enable + start now, and pick up the config on re-runs.
sudo systemctl enable --now keyd
sudo keyd reload || true

# Per-application overrides (user-level, NOT sudo): inside the terminal, make
# Super+C/V/W/A emit the terminal's Ctrl+Shift+* shortcuts so copy/paste/etc.
# work like a Mac while a bare Ctrl+C still interrupts. Applied by
# keyd-application-mapper, which on GNOME installs a small managing extension
# on first run.
mkdir -p "$HOME/.config/keyd"
cp "$REPO_DIR/keyd/app.conf" "$HOME/.config/keyd/app.conf"

# keyd-application-mapper needs a GNOME Shell extension to read the focused
# window on Wayland. The keyd package ships it, but its metadata may not list
# the very latest GNOME yet — so copy it to a writable location and add the
# running GNOME major version to its supported list (idempotent).
if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gnome-shell >/dev/null; then
  EXTDIR="$HOME/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com"
  GMAJOR="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
  if [[ ! -d "$EXTDIR" ]]; then
    mkdir -p "$HOME/.local/share/gnome-shell/extensions"
    cp -r /usr/share/keyd/gnome-extension-45 "$EXTDIR"
  fi
  tmp="$(mktemp)"
  jq --arg v "$GMAJOR" '."shell-version" |= (. + [$v] | unique)' \
    "$EXTDIR/metadata.json" > "$tmp" && mv "$tmp" "$EXTDIR/metadata.json"
  { set +x; } 2>/dev/null
  echo ">>> keyd GNOME extension staged for GNOME $GMAJOR. After your next"
  echo "    LOGOUT/LOGIN (required on Wayland), run these two commands once:"
  echo "      gnome-extensions enable keyd@keyd.rvaiya.github.com"
  echo "      keyd-application-mapper -d"
  { set -x; } 2>/dev/null
fi

# Super+L is freed for "focus URL bar" and Super+Q for "quit app", so move the
# lock-screen shortcut off both -> Super+Escape (a non-letter key untouched by
# the [meta] layer remaps).
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>Escape']"

# ---------------------------------------------------------------------------
# 8. GNOME desktop settings — macOS-style quality-of-life tweaks
#
#    All per-user (no sudo) and reversible. gsettings writes are idempotent.
# ---------------------------------------------------------------------------
step "Step 8/10  GNOME desktop settings (macOS-style QoL)"
# Window buttons: GNOME hides minimize/maximize by default — put them back.
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
# Blank the screen after 15 min idle (desktop), not the 5 min default.
gsettings set org.gnome.desktop.session idle-delay 900
# Lock 60s after the screen blanks instead of instantly (grace period).
gsettings set org.gnome.desktop.screensaver lock-delay 60
# Don't auto-suspend a workstation while on AC power.
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

# Window tiling like Rectangle (see RECTANGLE_KEYS.md): GNOME built-in halves +
# maximize via Super+arrows; quarters come from the Tiling Shell extension.
gsettings set org.gnome.mutter.keybindings toggle-tiled-left  "['<Super>Left']"
gsettings set org.gnome.mutter.keybindings toggle-tiled-right "['<Super>Right']"
gsettings set org.gnome.desktop.wm.keybindings maximize   "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']"

# Install Tiling Shell straight from extensions.gnome.org for the running GNOME
# version (no extensions-app needed). Enable after next login:
#   gnome-extensions enable tilingshell@ferrarodomenico.com
if command -v gnome-extensions >/dev/null && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
  TS_UUID="tilingshell@ferrarodomenico.com"
  if [[ ! -d "$HOME/.local/share/gnome-shell/extensions/$TS_UUID" ]]; then
    GVER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
    TS_DL="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${TS_UUID}&shell_version=${GVER}" | jq -r '.download_url')"
    if [[ -n "$TS_DL" && "$TS_DL" != "null" ]]; then
      curl -fsSL "https://extensions.gnome.org${TS_DL}" -o /tmp/tilingshell.zip \
        && gnome-extensions install --force /tmp/tilingshell.zip \
        && echo ">>> Tiling Shell installed — after login: gnome-extensions enable $TS_UUID"
    else
      echo ">>> No Tiling Shell build for GNOME $GVER yet; install via Extension Manager later."
    fi
  fi
fi

# Firefox add-on policy: auto-installs uBlock Origin, Vimium, Videospeed,
# 1Password, FireShot (see firefox/policies.json). Restart Firefox to apply.
sudo install -Dm644 "$REPO_DIR/firefox/policies.json" /etc/firefox/policies/policies.json

# ---------------------------------------------------------------------------
# 9. oh-my-zsh + make zsh the default shell
# ---------------------------------------------------------------------------
step "Step 9/10  Install oh-my-zsh + set zsh as default shell"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # Unattended install: doesn't run zsh or change the shell itself.
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# chsh needs util-linux-user on Fedora (installed via dnf.txt). Only change if needed.
ZSH_PATH="$(command -v zsh)"
if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  chsh -s "$ZSH_PATH" || echo "chsh failed — run manually: chsh -s $ZSH_PATH"
fi

# ---------------------------------------------------------------------------
# 10. Next steps
# ---------------------------------------------------------------------------
set +x
cat <<'STEPS'

============================================================================
  BOOTSTRAP COMPLETE — next steps (do these in order)
============================================================================

  1. REBOOT NOW. The NVIDIA akmod needs a reboot to load the driver.
       Verify after reboot:  nvidia-smi   (should list your RTX 5090)

  2. Log out and back in once more so the keyd swap + zsh default shell
     take full effect. Test: Ctrl now sits next to the spacebar.

  3. Generate an SSH key and add it to GitHub:
       ssh-keygen -t ed25519 -C "scottdnelson.coffee@gmail.com"
       eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
       cat ~/.ssh/id_ed25519.pub      # paste into github.com/settings/keys
     Or use the GitHub CLI:
       gh auth login                  # then: gh ssh-key add ~/.ssh/id_ed25519.pub

  4. Clone your dotfiles and create symlinks:
       git clone git@github.com:NelsonScott/dotfiles.git ~/dotfiles
     Then follow dotfiles-symlinks.md (run the ln commands one at a time).

  5. Install Claude Code:
       sudo npm install -g @anthropic-ai/claude-code

  6. Apply window-management shortcuts: see RECTANGLE_KEYS.md
     (install Tiling Shell from the GNOME Extensions site — link inside).

  7. Work through MIGRATION.md (apps) and CHROME_EXTENSIONS.md (Firefox).

============================================================================
STEPS
