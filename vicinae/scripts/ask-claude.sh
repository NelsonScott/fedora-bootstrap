#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Ask Claude
# @vicinae.mode fullOutput
# @vicinae.icon ✳️
# @vicinae.keywords ["ask","claude","ai","how do i","do this","fallback","help"]
# @vicinae.packageName Claude
# @vicinae.argument1 { "type": "text", "placeholder": "what do you want done?", "optional": false }
# One-shot: turns a plain-English request into ONE shell command, shown here first, never auto-run.
# Then use "Run Claude's Last Suggestion" or "Save Claude's Last Suggestion as Command".
# Vicinae runs under systemd --user with a minimal PATH; claude lives in ~/.npm-global/bin
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
Q="$1"; [[ -z "$Q" ]] && { echo "Type what you want done, e.g. 'ask mute the volume'"; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"; LAST="${XDG_RUNTIME_DIR:-/tmp}/vicinae-ask-last.json"
EXISTING=$(grep -h '^# @vicinae.title' "$HERE"/*.sh "$HERE"/*.py 2>/dev/null | sed 's/# @vicinae.title //' | paste -sd'; ')
SYS="You turn a desktop request into exactly ONE bash one-liner for this machine. Reply with ONLY a JSON object, no prose, no code fences:
{\"explanation\": \"one sentence\", \"command\": \"bash one-liner\", \"risk\": \"low|medium|high\", \"title\": \"2-4 word command name\", \"keywords\": [\"3-6 aliases\"]}
Machine: Fedora 44, GNOME Shell 50 on Wayland, zsh user. Tools available: gsettings, dconf, gdbus, notify-send, wpctl (audio), brightnessctl, xdg-open, variety (wallpaper), systemctl --user, ydotool (already running; keycodes 125=Super 29=Ctrl 56=Alt 42=Shift), flatpak, dnf (needs sudo => risk high).
Window control D-Bus (our extension): gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/DesktopActions --method org.scottnelson.DesktopActions.Tile X Y W H  (work-area fractions, e.g. 0 0 0.5 1 = left half); ...MinimizeAll.
GNOME screenshot D-Bus is denied to scripts; use ydotool 'key 42:1 125:1 5:1 5:0 125:0 42:0' for the screenshot UI. Screencast: org.gnome.Shell.Screencast.
risk=high for anything that deletes files, uses sudo, changes network/auth, or sends data off-machine. If the request already matches an existing command, set command to run it: existing commands are: $EXISTING."
# Slim context on purpose: no MCP servers, no CLAUDE.md/skills/hooks (a full-fat session costs ~100k tokens per ask).
OUT=$(cd /tmp && claude -p --model sonnet --max-turns 1 --no-session-persistence --output-format json \
        --strict-mcp-config --mcp-config '{"mcpServers":{}}' --setting-sources "" --tools "" \
        --system-prompt "$SYS" "$Q" </dev/null 2>&1) || { echo "claude failed:"; echo "$OUT" | tail -5; exit 1; }
python3 - "$OUT" "$LAST" "$Q" <<'PY'
import json, sys, re
raw, last, q = sys.argv[1:4]
try:
    d = json.loads(raw); txt = d.get('result', '')
    m = re.search(r'\{.*\}', txt, re.S); s = json.loads(m.group(0))
except Exception as e:
    print("Could not parse Claude's reply:\n", raw[:1500]); sys.exit(1)
s['question'] = q; json.dump(s, open(last, 'w'))
risk = s.get('risk', '?').upper(); flag = {'LOW': '🟢', 'MEDIUM': '🟡', 'HIGH': '🔴'}.get(risk, '⚪')
print(f"❓ {q}\n\n💡 {s.get('explanation','')}\n\n$ {s.get('command','')}\n\n{flag} risk: {risk}")
print("\nNext:  'run last'  → Run Claude's Last Suggestion" + ("  (blocked: high risk, copy it instead)" if risk == 'HIGH' else ''))
print(f"       'save last' → Save as command \"{s.get('title','')}\"  aliases: {', '.join(s.get('keywords', []))}")
u = d.get('usage', {}); print(f"\n({(u.get('input_tokens',0)+u.get('cache_creation_input_tokens',0)+u.get('cache_read_input_tokens',0))//1000}k ctx · {d.get('duration_api_ms',0)//1000}s · sonnet)")
PY
