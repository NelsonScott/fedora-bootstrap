#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Run Claude's Last Suggestion
# @vicinae.mode fullOutput
# @vicinae.icon ▶️
# @vicinae.keywords ["run last","run it","do it","execute","yes","claude run"]
# @vicinae.packageName Claude
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
LAST="${XDG_RUNTIME_DIR:-/tmp}/vicinae-ask-last.json"; [[ -f "$LAST" ]] || { echo "Nothing pending. Use 'Ask Claude' first."; exit 0; }
CMD=$(python3 -c "import json,sys; d=json.load(open('$LAST')); print(d['command'])"); RISK=$(python3 -c "import json; print(json.load(open('$LAST')).get('risk','').lower())")
[[ "$RISK" == "high" ]] && { echo "🔴 Refusing to run a HIGH-risk suggestion from the palette. Copy it and run it yourself:"; echo; echo "$CMD"; exit 1; }
echo "$ $CMD"; echo; sleep 0.3
bash -lc "$CMD" 2>&1; echo; echo "(exit $?)"
