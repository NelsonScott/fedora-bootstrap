#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Save Claude's Last Suggestion as Command
# @vicinae.mode fullOutput
# @vicinae.icon 💾
# @vicinae.keywords ["save last","save command","keep","remember this","claude save"]
# @vicinae.packageName Claude
LAST="${XDG_RUNTIME_DIR:-/tmp}/vicinae-ask-last.json"; [[ -f "$LAST" ]] || { echo "Nothing pending. Use 'Ask Claude' first."; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 - "$LAST" "$HERE" <<'PY'
import json, sys, re, os, stat
d = json.load(open(sys.argv[1])); here = sys.argv[2]
title = d.get('title') or d['question'][:30]; slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
path = os.path.join(here, 'saved', f'{slug}.sh'); os.makedirs(os.path.dirname(path), exist_ok=True)
kw = json.dumps(sorted(set(d.get('keywords', []) + [d['question']])))
open(path, 'w').write(f"""#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title {title}
# @vicinae.mode silent
# @vicinae.icon 🧩
# @vicinae.keywords {kw}
# @vicinae.packageName Saved
# Saved from Ask Claude. Question: {d['question']}
# {d.get('explanation','')}
{d['command']}
""")
os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)
print(f"Saved → {path}\nIt appears in search after the next script rescan (or run 'Reload Script Directories').")
PY
