# Vicinae — command palette (Super+Space)

Raycast-compatible launcher for Linux (https://github.com/vicinaehq/vicinae, ~9k stars).
Installed Aug 27 2026 from COPR `quadratech188/vicinae`. Removal: `sudo dnf remove vicinae`.

Why: I kept forgetting window shortcuts (hide all, corners). Wanted a Spotlight/Raycast box
where typing `hide windows` or `corners` offers the action. GNOME's overview search only does
apps/files/settings, not actions.

## What is intentionally OFF and why

| Setting | Reason |
|---|---|
| `input_server.enabled: false` | It is a uinput keyboard injector that also opens every `/dev/input/event*`. keyd owns the keyboard here. Cost: "paste to active window" degrades to "copy". |
| `global_shortcuts.toggle: ""` | Vicinae's own hotkey (portal) is disabled; the GNOME custom keybinding `vicinae toggle` is the single source of truth. |
| No `vicinae@dagimg-dot` GNOME extension | It would give Vicinae clipboard history + a window switcher. Copyous (Super+Shift+C) is the clipboard manager and Tiling Shell owns windows, so the clipboard provider stays a no-op. |
| `telemetry.system_info: false` | |

## Gotchas
- Config file is `~/.config/vicinae/settings.json`. A `vicinae.json` is silently ignored.
- The GUI rewrites `settings.json` (comments lost). Hand-kept values go in `scott.jsonc` via `imports`.
- First run drops `com.vicinae.vicinae.json` native-messaging manifests into every browser config dir. Harmless (1Password does the same).
- First run indexes `$HOME` for file search (a few minutes of CPU).
- Headless QA: `vicinae open`, portal screenshot (org.gnome.Shell.Screenshot D-Bus is denied), `vicinae state open`, `vicinae close`.

## Themes
`vicinae theme set <name>`; bundled list in `/usr/share/vicinae/themes/`. Template: `vicinae theme template`.

## TODO
- Script commands for GNOME/Tiling Shell actions (show desktop, halves/quarters, move to monitor, restart keyd mapper) with keyword aliases.
- `ask <text>` fallback that hands unmatched queries to Claude.

## Script commands (`scripts/`, symlinked to `~/.local/share/vicinae/scripts`)
| Command | Aliases | How it works |
|---|---|---|
| Hide All Windows | hide, desktop, minimize all | ydotool sends Ctrl+Super+Alt+H = GNOME `show-desktop` (bound by install.sh) |
| Window to Top-Left/Top-Right/Bottom-Left/Bottom-Right Corner | corner(s), quarter, tl/tr/bl/br | `org.scottnelson.DesktopActions.Tile x y w h` via `desktop-actions@scottnelson` |
| Window to Left/Right Half, Center Window | half, split, center | same |
| Take Screenshot | screenshot, snap, capture | ydotool Shift+Super+4 = GNOME screenshot UI |
| Record Screen (start/stop) | record, rec, screencast | `org.gnome.Shell.Screencast` D-Bus toggle, saves to ~/Videos/Screencasts |
| Claude Usage | usage, limits, quota | same OAuth endpoint as the top-bar extension, prints bars |
| Next Wallpaper | wallpaper, background | `variety -n` |

Why ydotool works here: ydotoold already runs as the user (dictation), and keyd ignores its virtual
keyboard (`-2333:6666`), so injected chords are real GNOME shortcuts, not keyd-remapped ones.
Why NOT Tiling Shell for corners: its move-window keys only move between tiles of the ACTIVE layout,
and a 2-column layout has no top/bottom tiles. Verified: Super+Left / move-up did nothing.
`org.gnome.Shell.Screenshot` D-Bus is denied to normal callers (Screencast is not) — hence ydotool for screenshots.

## Ask Claude (AI fallback)
`ask <anything>` → `scripts/ask-claude.sh` runs `claude -p` (sonnet, slim context: no MCP, no settings/CLAUDE.md, no tools,
~2-3 s) with a system prompt describing this machine and the installed commands. It prints explanation + the exact
command + a risk grade, and NEVER runs it. Then:
- `run last`  → `run-last-suggestion.sh` executes it (refuses risk=high; copy it yourself).
- `save last` → `save-last-suggestion.sh` writes `scripts/saved/<slug>.sh` with title + aliases, so next time it is a normal instant command.
Gotcha: Vicinae's systemd PATH lacks ~/.npm-global/bin and ~/.local/bin; scripts export PATH themselves.
