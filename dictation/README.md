# Double-tap-Ctrl dictation (macOS-style) for Fedora / GNOME / Wayland

Tap **Ctrl twice** → 🎤 recording starts. Tap twice again → speech is
transcribed **locally on the GPU** (OpenAI Whisper `large-v3` via
faster-whisper) and **typed into whatever window has focus** — terminal,
browser, anywhere. No cloud, nothing leaves the machine.

## How it works

```
double-tap Ctrl
      │  keyd: [main] leftcontrol = overload(control, oneshot(dtap))
      │        [dtap] leftcontrol = command(/usr/local/bin/dictate-toggle)
      ▼
/usr/local/bin/dictate-toggle          (run by keyd as root)
      │  writes 1 byte to /run/user/<uid>/dictate.fifo
      ▼
dictated.py                            (systemd user service, model preloaded)
      │  toggle 1: pw-record 16kHz mono → dictate.wav
      │  toggle 2: faster-whisper transcribe (CUDA fp16, VAD-trimmed)
      ▼
ydotool type                           (uinput virtual keyboard → any Wayland app)
```

Three deliberate choices, informed by what's broken in existing tools:

- **keyd trigger, not an evdev-sniffing listener.** keyd already sits below the
  compositor; the double-tap is one `oneshot` layer, no extra process with
  input-device privileges, no layout dependence.
- **ydotool, not wtype.** GNOME's Mutter doesn't implement
  `virtual-keyboard-unstable-v1`, so wtype (what most tools use) simply does
  not work on GNOME Wayland. uinput does.
- **Model preloaded in a daemon.** Load once at login (~1s), then every
  dictation transcribes at ~46x realtime on an RTX 5090 — a minute of speech
  becomes text in ~1.3s.

## Install

```sh
./install.sh          # venv + services + udev rule (sudo for 2 files)
```

plus the `[global]`/`[dtap]`/`leftcontrol` snippet in `../keyd/default.conf`
(applied automatically by bootstrap.sh; standalone users: merge it into
`/etc/keyd/default.conf` and `sudo keyd reload`). Also exclude ydotoold's
virtual keyboard in keyd's `[ids]` (`-2333:6666`) so typed output isn't
re-remapped.

## Config (env vars in `systemd/dictate.service`)

| var | default | notes |
|---|---|---|
| `DICTATE_MODEL` | `large-v3` | best quality; `large-v3-turbo` = ~half the VRAM (~1.6 GB), 2x speed, nearly equal accuracy |
| `DICTATE_LANG` | `en` | `auto` for language detection |
| `DICTATE_DEVICE` | `auto` | GPU with CPU-`small` fallback; `cuda` to require GPU |
| `DICTATE_KEY_DELAY` | `5` | ms/char for ydotool; raise if an Electron app drops chars |

## Known limits

- Text lands in whichever window is focused when transcription *finishes*
  (~0.3s after stop) — don't alt-tab mid-sentence.
- ydotool assumes US-QWERTY; unicode punctuation is normalized to ASCII.
- Ctrl-tap double counts only within 400ms (`oneshot_timeout`), like macOS.

## Ops

```sh
journalctl --user -fu dictate        # live log (timings, transcripts)
systemctl --user restart dictate     # after config edits
```
