# fedora-bootstrap

My personal setup for a fresh **Fedora 44 Workstation** install
(Ryzen 9 9950X + RTX 5090), migrating from macOS. Clone it on the new PC and run.

## What it does

`bootstrap.sh` takes a clean Fedora install to a working daily-driver:
system update → RPM Fusion → NVIDIA driver (5090/Blackwell) → my CLI packages →
Flatpak apps → Node.js → keyd (Alt↔Ctrl swap for Mac muscle memory) →
oh-my-zsh + zsh as default shell. The Markdown files are manual checklists for
the things you shouldn't fully automate (symlinks, app migration, browser
extensions, window shortcuts).

## Order of operations

```bash
# 1. Clone
git clone https://github.com/nelsonscott/fedora-bootstrap
cd fedora-bootstrap

# 2. Read bootstrap.sh top-to-bottom (it's short — see "Philosophy")
# 3. Run it (do NOT use sudo; it sudo's the bits that need it)
./bootstrap.sh

# 4. REBOOT — required for the NVIDIA driver. Then `nvidia-smi` to confirm.
# 5. Log out/in once more so keyd + zsh default shell fully apply.
# 6. SSH key → GitHub  (commands printed at end of bootstrap.sh)
# 7. Symlink dotfiles   → dotfiles-symlinks.md  (run lines one at a time)
# 8. Install Claude Code: sudo npm install -g @anthropic-ai/claude-code
# 9. Window shortcuts   → RECTANGLE_KEYS.md  (installs Tiling Shell)
# 10. App migration     → MIGRATION.md
# 11. Browser add-ons   → CHROME_EXTENSIONS.md
```

## Files

| File | Purpose |
|---|---|
| `bootstrap.sh` | The one script. Idempotent, `set -x`, safe to re-run. |
| `packages/dnf.txt` | DNF packages, one per line, `#` comments allowed. |
| `packages/flatpak.txt` | Flatpak app IDs (starts empty — add your own). |
| `zshrc` | Linux-adapted zshrc (symlink this, not the Mac one). |
| `dotfiles-symlinks.md` | Exact `ln -sfn` commands for the dotfiles repo. |
| `MIGRATION.md` | Every Mac app + brew tool → Fedora equivalent. |
| `CHROME_EXTENSIONS.md` | Each Chrome extension → Firefox add-on. |
| `RECTANGLE_KEYS.md` | Rectangle shortcuts → GNOME / Tiling Shell. |

## Adding a package later

- **CLI tool from Fedora repos:** add the package name to `packages/dnf.txt`
  (a line, with an optional `# why` comment) and re-run `./bootstrap.sh`.
- **GUI app from Flathub:** find the app ID at https://flathub.org (or
  `flatpak search <name>`), add it to `packages/flatpak.txt`, re-run.
- Re-running is always safe: already-installed things are skipped.

## Philosophy

- **Plain bash.** No chezmoi, stow, Ansible, or dotbot. You can read the whole
  thing in 10 minutes and know exactly what it does.
- **Idempotent.** Every step checks before it changes anything. Re-run anytime.
- **Visible.** `set -x` echoes each command so nothing happens behind your back.
- **Checklists over magic.** Symlinks, app choices, and browser extensions are
  Markdown you run by hand — migration is a judgment call, not a black box.
