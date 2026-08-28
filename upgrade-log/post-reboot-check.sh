#!/bin/bash
# Post-upgrade sanity check. Run after the 2026-08-28 upgrade reboot: bash ~/fedora-bootstrap/upgrade-log/post-reboot-check.sh
ok(){ printf '  \e[32mOK\e[0m   %s\n' "$*"; } ; bad(){ printf '  \e[31mFAIL\e[0m %s\n' "$*"; }
echo "== kernel";      k=$(uname -r); [[ $k == 7.1.10* ]] && ok "$k" || bad "running $k (expected 7.1.10-200.fc44)"
echo "== nvidia";      v=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null); [[ $v == 610.* ]] && ok "driver $v, GPU visible" || bad "nvidia-smi: ${v:-no GPU} (expected 610.57.04)"
                       s=$(modinfo nvidia 2>/dev/null | awk '/^signer/{print $2}'); [[ $s == fedora_1781752757* ]] && ok "module signed by MOK $s" || bad "module signer: ${s:-none}"
echo "== secure boot"; mokutil --sb-state 2>/dev/null | grep -q enabled && ok "Secure Boot enabled" || bad "Secure Boot state unexpected"
echo "== dbx";         d=$(fwupdmgr get-devices --json 2>/dev/null | python3 -c "import json,sys;print([x['Version'] for x in json.load(sys.stdin)['Devices'] if x.get('Name')=='UEFI dbx'][0])" 2>/dev/null); [[ $d == 20260402 ]] && ok "dbx $d" || bad "dbx version ${d:-unknown} (expected 20260402)"
echo "== gnome";       g=$(gnome-shell --version); [[ $g == *50.4* ]] && ok "$g" || bad "$g"
                       [[ $XDG_SESSION_TYPE == wayland ]] && ok "Wayland session" || bad "session type $XDG_SESSION_TYPE"
echo "== extensions";  want="tilingshell@ferrarodomenico.com copyous@boerdereinar.dev keyd@keyd.rvaiya.github.com dash-to-dock@micxgx.gmail.com azclock@azclock.gitlab.com desktop-actions@scottnelson claude-usage@scottnelson"
                       for e in $want; do st=$(gnome-extensions info $e 2>/dev/null | awk '/State/{print $2}'); [[ $st == ACTIVE ]] && ok "$e" || bad "$e state=${st:-missing}"; done
echo "== keyd";        systemctl is-active keyd >/dev/null && ok "keyd active" || bad "keyd not active"
                       pgrep -f "keyd-application-mapper" >/dev/null && ok "app mapper running" || bad "app mapper not running (nohup /usr/bin/keyd-application-mapper -d &)"
echo "== services";    for u in sous; do systemctl --user is-active $u >/dev/null 2>&1 && ok "user unit $u" || bad "user unit $u"; done
                       curl -sf -m 5 http://127.0.0.1:8477/health >/dev/null 2>&1 && ok "sous /health" || echo "  note sous /health not answering (may still be loading GPU model)"
echo "== howdy";       rpm -q howdy >/dev/null && ok "howdy installed; test: sudo -k; sudo true (face)" || bad "howdy missing"
echo "== wifi (info only)"; nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep wlp || echo "  no wlp device"
echo "== flatpak nvidia runtime"; d=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | tr . -); flatpak list --columns=application 2>/dev/null | grep -q "GL.nvidia-$d" && ok "flatpak GL runtime nvidia-$d present" || bad "flatpak GL runtime for nvidia-$d MISSING: sudo flatpak update -y"
echo "== dkms";        sudo dkms status 2>/dev/null | sed 's/^/  /'
echo "== journal errors this boot (top 5)"; journalctl -b -p err --no-pager 2>/dev/null | tail -5 | cut -c1-160 | sed 's/^/  /'
