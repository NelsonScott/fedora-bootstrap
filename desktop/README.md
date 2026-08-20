# desktop — Mac-like GNOME 50 restyle + wallpaper rig

Run by `bootstrap.sh` step 11, or standalone: `./desktop/install.sh` (idempotent).

## What you get

- **Shell**: Kiwi + Kiwi Menu (Mac-style panel/menu), Rounded Window Corners
  Reborn (rounds every window, Chrome/Electron included), Rounded Corners
  (screen edges), Just Perfection. Fresh extensions load at the next login.
- **Look**: macOS cursor at 48px (Wayland doesn't scale cursors — 24px is tiny
  at 4K), WhiteSur dark icons, window buttons right, dock icons 84px.
- **Qt apps** (CopyQ, …): qt6ct + Kvantum `KvArcDark` so they stop looking
  like 2005. `environment.d` covers future logins — but see the linger gotcha
  in `install.sh` comments.
- **Wallpaper**: Variety rotating every 2h from Bing UHD + Unsplash (≥4K,
  patched) — plus a styled quote overlay and a **ticking clock** styled to
  match, via a patched `QuoteWriter.py`. Switch looks with
  `variety-style {a|b|c} [top]` (current daily driver: `b top` — Cormorant
  quote bottom-centre, clock top-centre).

## Gotchas encoded here (learned the hard way)

| Gotcha | Consequence | Where handled |
|---|---|---|
| GDK misdetects the display on Wayland ([variety#863](https://github.com/varietywalls/variety/issues/863)) | 1980px wallpapers on a 4K screen, portrait-cropped overlays | `GDK_BACKEND=x11` in autostart + `screen_size` pin (Util patch) |
| Negative clock offsets eaten by strftime ([variety#862](https://github.com/varietywalls/variety/issues/862), [PR#864](https://github.com/varietywalls/variety/pull/864)) | `[%HOFFSET-3]` → `[15OFFSET-3]`, magick fails silently | `variety-style` only emits `+N` offsets |
| ImageMagick can't select a weight from a variable font | Clock renders at the thin default master | Static instances cut with fontTools |
| Fedora ships stock wallpapers as `.jxl` | Variety sees 0 images in `/usr/share/backgrounds` | Source disabled |
| `fc-match` backticks in stock `clock_filter` never execute (fixed upstream, broken in Fedora's 0.9.0) | Stock clock never renders | `variety-style` uses font file paths |
| Lingering user services block `environment.d` refresh | Qt/cursor env vars silently missing after re-login | Comment + manual `set-environment` line in `install.sh` |

**After any `dnf update` that touches variety:** run
`~/.config/variety/patches/reapply.sh`.

**Manual step:** Wallhaven API key (wallhaven.cc/settings/account) is not
committed — the installer prints a reminder.

## ⚠️ Do not install

**Blur my Shell** — v72 has a confirmed OOM leak on GNOME 50.2 Wayland +
NVIDIA (gnome-shell → 16–25 GB RSS → session killed). Wait for the release
containing the fix: [blur-my-shell#957](https://github.com/aunetx/blur-my-shell/issues/957).

**Full GTK themes** (WhiteSur/Orchis/Graphite/…) — only ~2 GTK3 apps remain
here; libadwaita apps ignore them, and their GNOME Shell CSS is frozen at
GNOME 48.

## Not encoded (deliberately)

- Display scaling / monitor layout (hardware-specific): 4K DP-4 at 125%
  fractional scaling, 1080p portrait at x=3072. Set in Settings → Displays.
- Clipboard manager: in flux (Copyous on trial vs CopyQ).
- "Phase 3" (Marble shell theme + custom palette): undecided.
