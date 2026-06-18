# Rectangle → GNOME / Tiling Shell

Translated from your `com.knollsoft.Rectangle.plist`. You ran Rectangle with
**alternate defaults** (`alternateDefaultShortcuts = true`, i.e. Ctrl+Option
based) plus three custom overrides.

We're going **Super-based** on Fedora (your choice). This is the most Mac-like
mapping and — importantly — **the Super key is NOT touched by your keyd Alt↔Ctrl
swap**, so these shortcuts stay rock-solid no matter what keyd does to Alt/Ctrl.

---

## What your Rectangle plist actually had

| Action | Your Mac shortcut | Source |
|---|---|---|
| Maximize | **Ctrl+Option+Cmd+M** | custom override |
| Top-left quarter | **Cmd+Option+Shift+←** | custom override |
| Top-right quarter | **Cmd+Option+Shift+→** | custom override |
| Left half | Ctrl+Option+← | Rectangle alt-default |
| Right half | Ctrl+Option+→ | Rectangle alt-default |
| Top / Bottom half | Ctrl+Option+↑ / ↓ | Rectangle alt-default |
| Other quarters / center | Ctrl+Option+U/I/J/K, etc. | Rectangle alt-defaults |

## New Fedora mapping (Super-based)

| Action | New shortcut | Provided by |
|---|---|---|
| Left half | **Super+←** | GNOME built-in |
| Right half | **Super+→** | GNOME built-in |
| Maximize | **Super+↑** | GNOME built-in |
| Restore / unmaximize | **Super+↓** | GNOME built-in |
| Top-left quarter | **Super+U** | Tiling Shell |
| Top-right quarter | **Super+I** | Tiling Shell |
| Bottom-left quarter | **Super+J** | Tiling Shell |
| Bottom-right quarter | **Super+K** | Tiling Shell |
| Center | **Super+C** | Tiling Shell (optional) |

---

## 1. Install Tiling Shell

`bootstrap.sh` doesn't auto-install GNOME extensions (you don't have
gnome-extensions-app on a fresh box). Install it from the web:

1. Open **Firefox** and go to: https://extensions.gnome.org/extension/7065/tiling-shell/
2. Install the browser integration when prompted (the page links the
   `chrome-gnome-shell` / GNOME Shell integration add-on), then flip the
   extension toggle to **ON**.
3. If the toggle is greyed out, install the host connector once:
   ```bash
   sudo dnf install -y gnome-browser-connector
   ```
   then reload the page.

Alternatively, CLI install without the website:
```bash
sudo dnf install -y gnome-shell-extension-manager   # GUI manager, optional
# or pipx:
pipx install gnome-extensions-cli && gext install tilingshell@ferrarodomenico.com
```

## 2. GNOME built-in halves + maximize (reliable, set via gsettings)

Copy-paste this block. It's idempotent — re-running just re-sets the same keys:

```bash
# Half-tiling left/right
gsettings set org.gnome.mutter.keybindings toggle-tiled-left  "['<Super>Left']"
gsettings set org.gnome.mutter.keybindings toggle-tiled-right "['<Super>Right']"

# Maximize / restore
gsettings set org.gnome.desktop.wm.keybindings maximize   "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']"
```

> GNOME's `toggle-tiled-left/right` already behave almost exactly like
> Rectangle's left/right half — this is the closest thing to a drop-in.

## 3. Quarter-tiling via Tiling Shell

Tiling Shell stores its keybindings under its own dconf schema. Exact key names
vary by version, so the **reliable** path is its Preferences UI:

> Extension Manager → Tiling Shell → **Settings → Keybindings** → set the four
> quarters to **Super+U / Super+I / Super+J / Super+K** (matching the table).

If you prefer the command line, the keys live here (inspect first, since names
differ between releases):

```bash
# See what's available for Tiling Shell:
dconf dump /org/gnome/shell/extensions/tilingshell/

# Example shape (verify the exact key names from the dump above before setting):
# dconf write /org/gnome/shell/extensions/tilingshell/tile-top-left-quarter  "['<Super>u']"
# dconf write /org/gnome/shell/extensions/tilingshell/tile-top-right-quarter "['<Super>i']"
```

## 4. Free up Super combos if GNOME grabs them

A couple of these (e.g. Super+U) may be bound by GNOME by default. If a
shortcut doesn't take, clear the conflicting binding, e.g.:

```bash
# Example: Super+I is sometimes bound to settings/screenshot in some spins
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "[]"
```

Check conflicts in **Settings → Keyboard → View and Customize Shortcuts** and
remove any that collide with Super+U/I/J/K.

---

### Note on the keyd swap

Because all of the above use **Super** (not Alt/Ctrl), your keyd Alt↔Ctrl swap
has zero effect on window management. If you ever DO want a Ctrl/Alt-based
shortcut, remember keyd rewrites those keys system-wide before GNOME sees them,
so bind to the *physical* key's *new* meaning (physical Alt now sends Ctrl).
