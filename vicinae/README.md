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
