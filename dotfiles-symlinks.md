# Dotfiles symlinks (run manually, one at a time)

This walks you through linking your `nelsonscott/dotfiles` files into place on
Fedora. Run each command yourself so you see exactly what happens. Every step
backs up an existing file into `/tmp` first (`mv ~/.x /tmp/.x.backup`) so nothing
is clobbered. (`/tmp` exists on Fedora and is cleared on reboot — grab a backup
from there before you restart if you want to keep it.)

**Assumptions**
- You cloned dotfiles to `~/dotfiles`:
  ```bash
  git clone git@github.com:NelsonScott/dotfiles.git ~/dotfiles
  ```
- This bootstrap repo is at `~/fedora-bootstrap`.
- `ln -sfn` = symlink, force, no-deref (so re-running replaces the link, not nests it).

> **Key difference from your Mac:** for `.zshrc` you link the **bootstrap repo's
> Linux-adapted `zshrc`**, not `~/dotfiles/zshrc` (which is full of macOS-only
> paths). Everything else links from `~/dotfiles` as usual.

---

## 1. `.zshrc`  → bootstrap repo's Linux version

```bash
# Back up anything already there (oh-my-zsh may have written a default one)
[ -e ~/.zshrc ] && mv ~/.zshrc /tmp/.zshrc.backup
ln -sfn ~/fedora-bootstrap/zshrc ~/.zshrc
```

## 2. `.vimrc`  → dotfiles/vimrc

```bash
[ -e ~/.vimrc ] && mv ~/.vimrc /tmp/.vimrc.backup
ln -sfn ~/dotfiles/vimrc ~/.vimrc
```

## 3. `.gitconfig`  → dotfiles/gitconfig

```bash
[ -e ~/.gitconfig ] && mv ~/.gitconfig /tmp/.gitconfig.backup
ln -sfn ~/dotfiles/gitconfig ~/.gitconfig
```

> ⚠️ Your gitconfig sets the **Kaleidoscope** diff/merge tool (macOS-only, no
> Linux build). Those lines are inert until you run `git df`/`git mergetool`,
> which will then fail. On Linux, install Meld (`sudo dnf install -y meld`) and
> override:
> ```bash
> git config --global diff.tool meld
> git config --global merge.tool meld
> ```
> Also note `[hub] protocol = ssh` — on Linux use `gh` instead of `hub`
> (your `fast_c` function already does).

## 4. `bin/transcribe`  → ~/.local/bin/transcribe

```bash
mkdir -p ~/.local/bin
[ -e ~/.local/bin/transcribe ] && mv ~/.local/bin/transcribe /tmp/transcribe.backup
ln -sfn ~/dotfiles/bin/transcribe ~/.local/bin/transcribe
```

> ⚠️ `transcribe` hardcodes a macOS WhisperX path
> (`/opt/homebrew/Caskroom/miniconda/.../whisperx`). On Linux, install whisperx
> (e.g. a conda/venv or `pipx`) and edit `WHISPERX_BIN` in the script to point
> at it. It also needs `HF_TOKEN` (already in your `.env`).

---

## Intentionally NOT linked on Linux

- **`bash_profile` / `bashrc`** — they're macOS Homebrew/conda/RVM bootstraps
  ("ancient, using zsh primarily" per your own README). Skip them; you default
  to zsh anyway.
- **`pi/zshrc`** — that's for your Raspberry Pi, not this desktop.
- **`install.conf.yaml` / `dotbot/`** — you chose plain bash over dotbot.

## Verify

```bash
ls -la ~/.zshrc ~/.vimrc ~/.gitconfig ~/.local/bin/transcribe
# Each should show:  -> /home/scott/dotfiles/...  (or fedora-bootstrap for zshrc)
exec zsh   # reload into the new shell
```
