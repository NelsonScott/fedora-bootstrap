# keymap — every keybinding on this PC, on one page (Cmd+/)

Omarchy has Super+K; this is ours. Press **Cmd+/** and a full-screen page lists every
binding, read LIVE from where each one actually lives (never from this repo):

| source | what |
|---|---|
| `/etc/keyd/default.conf` | keyd global: the Cmd layer, Opt text nav, swaps, dictation |
| `~/.config/keyd/app.conf` | keyd per-app overrides (Terminal, Chrome, Firefox) |
| dconf: wm / shell / mutter / media-keys / custom | GNOME shortcuts, ★ = set by you |
| Tiling Shell schema, `/org/gnome/Ptyxis` | extension + terminal shortcuts |

Top banner = health: keyd up, app-mapper alive and reading `keyd.fifo`, keyd GNOME
extension enabled, user in `keyd` group, live confs == `keyd/` in this repo, and any
user-set GNOME chord that keyd would eat before GNOME sees it (this is why the page is on
Cmd+/ and not Cmd+K: keyd maps Cmd+K to Ctrl+K for Obsidian).

Files: `keymap.py` (parser; `--format html|table|dmenu|json`, `--health`), `html_out.py`
(page), `keys-page.sh` (what Cmd+/ runs: regenerate to `~/.cache/keymap/keymap.html`, open
as a Chrome app window; Cmd+W closes), `keys-menu.sh` (Vicinae dmenu variant, unbound),
`qa-shot.py` (portal screenshot for headless QA), `install.sh` (binds Cmd+/).

Known gaps: "focused app" highlight needs the desktop-actions extension (loads after a
re-login); Vimium (Chrome) and app-internal shortcuts other than Ptyxis are not read.
