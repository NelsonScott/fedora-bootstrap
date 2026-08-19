#!/usr/bin/env bash
# Idempotent installer for double-tap-Ctrl Whisper dictation.
# Run as the desktop user (it will sudo only for the two root-owned bits).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/dictate"

echo ">>> dictation: python venv + faster-whisper"
mkdir -p "$DEST"
# --system-site-packages: evdev (Esc-cancel) comes from the python3-evdev RPM
[[ -x "$DEST/venv/bin/python" ]] || python3 -m venv --system-site-packages "$DEST/venv"
grep -q "include-system-site-packages = true" "$DEST/venv/pyvenv.cfg" || \
  sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$DEST/venv/pyvenv.cfg"
"$DEST/venv/bin/pip" install -q --upgrade pip faster-whisper
rpm -q python3-evdev >/dev/null 2>&1 || sudo dnf install -y python3-evdev

echo ">>> dictation: daemon + toggle script"
install -m 0755 "$HERE/dictated.py" "$DEST/dictated.py"
# keyd runs the toggle as root, so it lives in a root-owned path.
sudo install -m 0755 "$HERE/dictate-toggle" /usr/local/bin/dictate-toggle

echo ">>> dictation: /dev/uinput access for ydotoold (user-level)"
sudo tee /etc/udev/rules.d/99-uinput-dictate.rules >/dev/null <<'EOF'
KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess"
EOF
sudo udevadm control --reload && sudo udevadm trigger /dev/uinput || true

echo ">>> dictation: Esc-cancel needs read access to keyd's virtual keyboard"
sudo tee /etc/udev/rules.d/99-dictate-input.rules >/dev/null <<'EOF'
KERNEL=="event*", ATTRS{name}=="keyd virtual keyboard", TAG+="uaccess"
EOF
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=input || true

echo ">>> dictation: Nemotron streaming engine (own py3.12 venv — NeMo does not"
echo "    build on Fedora's newer system Python; this install is several GB)"
rpm -q python3.12 python3.12-devel >/dev/null 2>&1 || sudo dnf install -y python3.12 python3.12-devel
[[ -x "$DEST/nemo-venv/bin/python" ]] || python3.12 -m venv "$DEST/nemo-venv"
"$DEST/nemo-venv/bin/pip" install -q --upgrade pip
"$DEST/nemo-venv/bin/pip" install -q "nemo_toolkit[asr]"
install -m 0755 "$HERE/nemotron_stream.py" "$DEST/nemotron_stream.py"

echo ">>> dictation: systemd user services"
mkdir -p "$HOME/.config/systemd/user"
install -m 0644 "$HERE/systemd/ydotoold.service" "$HOME/.config/systemd/user/"
install -m 0644 "$HERE/systemd/dictate.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now ydotoold.service dictate.service

cat <<'EOF'
>>> dictation installed.
    Trigger: requires the keyd [dtap] snippet (see keyd/default.conf in this
    repo) — double-tap Ctrl toggles recording.
    First start downloads the Whisper model (~3 GB for large-v3); watch:
        journalctl --user -fu dictate
EOF
