# Migration checklist: Mac apps → Fedora

Generated from your real `/Applications` folder and `brew list`. Each row is a
checkbox so you can track what you've moved. Install method is one of
**dnf** / **flatpak** / **other** (vendor repo or download) / **web**.

> Honest grouping: "Obvious equivalents" install in one command. "Web app
> alternatives" have no native Linux app but work fine in a browser/PWA.
> "No good Linux equivalent" means exactly that — with the least-bad workaround.
>
> Trimmed to the apps you actually want to bring over — browsers, editor, and a
> pile of media/emulator/utility apps were removed on your call.

---

## /Applications

### ✅ Obvious equivalents (native Linux, install directly)

- [ ] **VLC** — `org.videolan.VLC` (or dnf via RPM Fusion) (install via: **flatpak / dnf**)
- [ ] **Docker Desktop** — Docker Engine via `docker-ce` repo, or use **podman** (preinstalled) (install via: **other**)
- [ ] **Steam** — `com.valvesoftware.Steam` (recommended for NVIDIA), or dnf via RPM Fusion (install via: **flatpak / dnf**)
- [ ] **Datadog Agent** — Datadog's official Linux install script/repo (install via: **other**)
- [ ] **Maccy** (clipboard manager) — **CopyQ** `sudo dnf install copyq`, or GNOME "Clipboard Indicator" extension (install via: **dnf**)

### 🌐 Web app alternatives (no native app — use browser/PWA)

- [ ] **Amazon Kindle** — read.amazon.com (Kindle Cloud Reader) (install via: **web**)
- [ ] **Claude** (desktop) — claude.ai (no official Linux desktop app) (install via: **web**)
- [ ] **Google Docs / Sheets / Slides / Drive** (the .app shortcuts) — these are
      Chrome PWAs; just bookmark/PWA them in Firefox or Chrome (install via: **web**)
- [ ] **Notion Calendar** — calendar.notion.so (install via: **web**)
- [ ] **Gmail/Google "Google Docs.app" etc.** — covered by web above

### ❌ No good Linux equivalent — workaround noted

- [ ] **Alfred 5** (launcher/workflows) — workaround: GNOME Activities search
      (built-in) for basic launching; **Ulauncher** or **Albert** for Alfred-like
      workflows (install via: **other / dnf**). No 1:1 replacement for Alfred workflows.
- [ ] **1Password** (desktop) — there IS a Linux app, but no Flathub/dnf repo;
      workaround: install from 1Password's official `.rpm` / their repo
      (downloads.1password.com) (install via: **other**)
- [ ] **Google Drive** (desktop sync) — no official Linux client; workaround:
      **GNOME Online Accounts** for Files integration, or **Insync** (paid)
      (install via: **dnf / other**)
- [ ] **Rectangle** — replaced by this repo: GNOME shortcuts + Tiling Shell.
      See **RECTANGLE_KEYS.md**.

---

## brew list

> Your `brew list` is ~200 entries, but the vast majority are **transitive
> library dependencies** auto-pulled by ffmpeg, imagemagick, opencv, gcc, and
> the Python stack (everything matching `lib*`, `*@<version>`, codec names like
> `x264/x265/dav1d/aom/svt-av1`, `openssl@*`, `icu4c@*`, etc.). You don't install
> those by hand on Fedora — dnf pulls them as deps. Below are the **top-level
> tools you actually invoke**, mapped to Fedora.

### CLI tools — in Fedora repos (install via **dnf**)

- [ ] **git, wget, curl, jq, fzf, htop, gh, nmap, watch, telnet, pandoc,
      smartmontools, imagemagick, ffmpeg, tesseract, gradle, kotlin** — all `dnf install`
- [ ] **yt-dlp** — `dnf install yt-dlp` (drop the deprecated `youtube-dl`)
- [ ] **thefuck, autojump, cowsay, fortune-mod, lolcat** — already in `packages/dnf.txt`
- [ ] **openjdk / openjdk@17** — `dnf install java-21-openjdk java-17-openjdk`
- [ ] **pipenv** — via `pipx install pipenv`

### Casks (GUI) — already covered in /Applications above

- [ ] **1password-cli** — 1Password's repo provides `1password-cli` (install via: **other**)
- [ ] **rectangle, maccy, webviewscreensaver** — see /Applications section
      (Tiling Shell, CopyQ, GNOME screensaver respectively)
