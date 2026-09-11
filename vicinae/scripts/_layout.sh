# Shared helper: switch the Tiling Shell layout on one monitor, for every workspace.
# Tiling Shell stores `selected-layouts` as [workspace][monitor] -> layout id and
# re-reads it live (globalState.js listens on changed::selected-layouts), so a
# plain dconf write is enough. Monitor 0 = Samsung 32" (primary), 1 = Samsung 22"
# (verified Aug 31 2026: the 5-tile layout Scott picked on the 32" landed in slot 0).
# Layout ids are the names in Tiling Shell's layouts-json (renamed Aug 31 2026 to "5 Tiles", "3 Columns",
# "1/3 + 2/3", "2/3 + 1/3", "Top / Bottom" so they match the Vicinae titles).
set_layout() {  # set_layout "<layout id>" [monitor-index]
  local id="$1" mon="${2:-0}"
  python3 - "$id" "$mon" <<'PY'
import ast, subprocess, sys
lid, mon = sys.argv[1], int(sys.argv[2])
key = '/org/gnome/shell/extensions/tilingshell/selected-layouts'
raw = subprocess.run(['dconf', 'read', key], capture_output=True, text=True).stdout.strip()
cur = ast.literal_eval(raw) if raw else [['Layout 1', 'Layout 2']]
cur = [list(ws) for ws in cur]
for ws in cur:
    while len(ws) <= mon: ws.append(ws[-1] if ws else lid)
    ws[mon] = lid
subprocess.run(['dconf', 'write', key, repr(cur)], check=True)
PY
}
