# fedora-bootstrap

How I moved from a Mac to **Fedora 44 Workstation** (GNOME 50, Wayland, NVIDIA RTX 5090)
and made it feel like home. One plain bash script for the fresh install, plus the configs
and fixes I collected over the following months.

It is my machine, not a distro. Some pieces are tied to my hardware (5090, Logitech Brio,
Blue Yeti, a 4K monitor). Read a piece before you run it, and take what is useful.

<!-- screenshot: desktop.png goes here -->

## The useful bits, if you are coming from a Mac

| Piece | What it gives you | Where |
|---|---|---|
| **Cmd key that works** | keyd swaps the bottom row so the key next to space acts like Cmd: Cmd+C/V/X/T/W/Q, Option word-jumps. Per-app overrides so in the terminal Cmd+C copies and Ctrl+C still interrupts. | [`keyd/`](keyd/) |
| **Spotlight / Raycast** | [Vicinae](https://github.com/vicinaehq/vicinae) on Super+Space, with script commands for window corners and layouts, every GNOME Settings panel, Steam, screenshots, and asking Claude. | [`vicinae/`](vicinae/) |
| **Mac-ish desktop** | Dash to Dock, Kiwi (Mac-style panel and menu), rounded window corners, macOS cursor, WhiteSur icons, Qt apps themed to match. | [`desktop/`](desktop/) |
| **Wallpapers with quotes and a clock** | Variety rotating 4K Bing and Unsplash images, with a styled quote and clock drawn on. Includes fixes for Variety on Wayland and fractional scaling. | [`desktop/variety/`](desktop/variety/) |
| **Rectangle replacement** | My Rectangle shortcuts mapped to Tiling Shell. | [`RECTANGLE_KEYS.md`](RECTANGLE_KEYS.md) |
| **Every shortcut on one page** | Cmd+/ opens a page listing every keybinding on the system, read live from keyd and GNOME, with a health check for conflicts. | [`keymap/`](keymap/) |
| **App migration list** | Each Mac app and brew tool, with its Fedora equivalent or the least-bad workaround. | [`MIGRATION.md`](MIGRATION.md) |
| **Browser add-ons** | Chrome extensions mapped to Firefox add-ons, Vimium settings. | [`FIREFOX_EXTENSIONS.md`](FIREFOX_EXTENSIONS.md), [`vimium/`](vimium/) |
| **Face unlock** | Howdy with an IR webcam, including the SELinux module GDM needs. | [`faceauth/`](faceauth/) |
| **Living next to a Mac** | BlueBubbles (iMessage via your Mac) with a one-key unfreeze for its NVIDIA redraw bug. | [`desktop/bin/bbfix`](desktop/bin/bbfix) |
| **AirDrop-ish** | LocalSend set up so iPhone screenshots land in a folder. | [`desktop/localsend/`](desktop/localsend/) |

Dictation (double-tap Ctrl, local Whisper) started here and grew into its own project:
[speakwrite](https://github.com/NelsonScott/speakwrite).

## The fresh install

```bash
git clone https://github.com/NelsonScott/fedora-bootstrap
cd fedora-bootstrap
less bootstrap.sh     # read it first, it is short
./bootstrap.sh        # no sudo, it asks for sudo where needed
```

`bootstrap.sh` does: system update, RPM Fusion, the NVIDIA driver, CLI packages from
[`packages/dnf.txt`](packages/dnf.txt), Flatpaks from
[`packages/flatpak.txt`](packages/flatpak.txt), Node.js, keyd, and zsh with oh-my-zsh.
Then reboot (the NVIDIA driver needs it) and check `nvidia-smi`.

After that, the rest is checklists you run by hand:
[`dotfiles-symlinks.md`](dotfiles-symlinks.md), [`RECTANGLE_KEYS.md`](RECTANGLE_KEYS.md),
[`MIGRATION.md`](MIGRATION.md), [`FIREFOX_EXTENSIONS.md`](FIREFOX_EXTENSIONS.md), and
`desktop/install.sh` / `vicinae/install.sh` if you want those.

## How it is built

- **Plain bash.** No chezmoi, stow, Ansible, or dotbot. You can read it in 10 minutes.
- **Safe to re-run.** Every step checks before it changes anything.
- **Visible.** `set -x`, so you see every command.
- **Checklists over magic.** Moving apps is a judgment call, so those parts are Markdown.

## Gotchas I hit (so you don't)

- **RTX 5090 / Blackwell:** there is no special package, RPM Fusion's `akmod-nvidia` is the
  right one. With Secure Boot on, enroll the akmods MOK key once and kernel updates re-sign
  the module automatically.
- **Vicinae script commands get killed about 10 s after launch.** Never `exec` a GUI app from
  one; detach it with `setsid -f`. That was GNOME Settings "crashing" whenever I opened it.
- **keyd per-app bindings need your user in the `keyd` group**, or they silently do nothing.
- **Variety on Wayland misdetects the screen size**, so you get 1980px wallpapers on 4K.
  The fix is in [`desktop/README.md`](desktop/README.md).

More in each folder's README.

---

Built with help from Claude (like most things these days). It runs my daily driver, but
I haven't tested it on anyone else's hardware, so treat it as a reference rather than
an installer.
