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
step "Step 1/9  System upgrade (dnf upgrade -y)"
sudo dnf upgrade -y

# ---------------------------------------------------------------------------
# 2. RPM Fusion (free + nonfree) — needed for NVIDIA drivers, codecs, Steam...
#    Idempotent: dnf install of an already-installed release rpm is a no-op.
# ---------------------------------------------------------------------------
step "Step 2/9  Enable RPM Fusion (free + nonfree)"
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
step "Step 3/9  NVIDIA driver for RTX 5090 (akmod-nvidia + CUDA) — REBOOT after!"
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
# Kick off the module build now so it's ready by the time you reboot.
sudo akmods --force || true

# ---------------------------------------------------------------------------
# 4. DNF packages (from packages/dnf.txt)
# ---------------------------------------------------------------------------
step "Step 4/9  Install DNF packages from packages/dnf.txt"
if [[ -f "$DNF_LIST" ]]; then
  # One `dnf install` call with the whole list: idempotent and fast.
  # shellcheck disable=SC2046
  sudo dnf install -y $(read_pkg_list "$DNF_LIST")
fi

# ---------------------------------------------------------------------------
# 5. Flatpak apps (from packages/flatpak.txt)
# ---------------------------------------------------------------------------
step "Step 5/9  Set up Flathub + install Flatpak apps from packages/flatpak.txt"
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
step "Step 6/9  Install Node.js + npm (for Claude Code)"
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
# 7. keyd — swap Alt <-> Ctrl (true swap)
#
#    Goal: Ctrl lands on the key right next to the spacebar (where Cmd is on
#    your Mac), so Ctrl+C / Ctrl+V feel like Cmd+C / Cmd+V. Alt moves to the
#    old Ctrl key, so nothing is lost (Alt+Tab etc. still work, just shifted).
#
#    keyd is a system-level remapper that works on both X11 and Wayland and
#    is unaffected by the desktop. The config below applies to all keyboards.
# ---------------------------------------------------------------------------
step "Step 7/9  Install + configure keyd (Alt<->Ctrl swap)"
sudo dnf install -y keyd

sudo mkdir -p /etc/keyd
sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
# Managed by fedora-bootstrap. True Alt<->Ctrl swap for Mac muscle memory:
# the key next to the spacebar becomes Ctrl; Alt moves to the old Ctrl key.
#
# To revert: delete this file (or comment the lines) and `sudo keyd reload`.
# To keep the right Alt as a real Alt (AltGr), delete the two `right*` lines.

[ids]
*

[main]
leftalt      = leftcontrol
leftcontrol  = leftalt
rightalt     = rightcontrol
rightcontrol = rightalt
EOF

# Enable + start now, and pick up the config on re-runs.
sudo systemctl enable --now keyd
sudo keyd reload || true

# ---------------------------------------------------------------------------
# 8. oh-my-zsh + make zsh the default shell
# ---------------------------------------------------------------------------
step "Step 8/9  Install oh-my-zsh + set zsh as default shell"
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
# 9. Next steps
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
