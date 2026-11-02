#!/bin/bash
# Merge vimium-settings.json into Firefox's Vimium settings (extension storage.sync).
# Vimium keeps settings ONLY in storage.sync: for Firefox that is one JSON row per extension in
# <profile>/storage-sync-v2.sqlite. Firefox holds that DB open, so it must be closed first.
# Same file also works by hand: Vimium Options -> Backup and Restore -> Restore.
# Chrome needs nothing: its storage.sync rides Google Sync.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VIMIUM_ID='{d7742d87-e61d-4b78-b8a1-b469842139fa}'
FFDIR="$HOME/.config/mozilla/firefox"
if pgrep -x firefox >/dev/null || pgrep -x firefox-bin >/dev/null; then
    echo "Firefox is running: close it first (it holds storage-sync-v2.sqlite)." >&2; exit 1
fi
# The profile Firefox actually launches = the [Install...] Default= in profiles.ini.
PROFILE="$(awk -F= '/^\[Install/{i=1} i&&/^Default=/{print $2; exit}' "$FFDIR/profiles.ini")"
DB="$FFDIR/$PROFILE/storage-sync-v2.sqlite"
[[ -f "$DB" ]] || { echo "no $DB" >&2; exit 1; }
cp -a "$DB" "$DB.bak-$(date +%Y%m%d-%H%M%S)"
python3 - "$DB" "$VIMIUM_ID" "$HERE/vimium-settings.json" <<'PY'
import json, sqlite3, sys
db, ext, src = sys.argv[1:4]
want = json.load(open(src))
con = sqlite3.connect(db)
row = con.execute("SELECT data, sync_change_counter FROM storage_sync_data WHERE ext_id=?", (ext,)).fetchone()
data = json.loads(row[0]) if row and row[0] else {}
data.update(want)   # merge: keep any other Vimium settings already there
con.execute("INSERT INTO storage_sync_data(ext_id, data, sync_change_counter) VALUES(?,?,1) "
            "ON CONFLICT(ext_id) DO UPDATE SET data=excluded.data, sync_change_counter=sync_change_counter+1",
            (ext, json.dumps(data)))
con.commit(); con.execute("PRAGMA wal_checkpoint(TRUNCATE)"); con.close()
print("Vimium settings now:", json.dumps(data)[:200])
PY
