#!/usr/bin/env python3
# @vicinae.schemaVersion 1
# @vicinae.title Claude Usage
# @vicinae.mode fullOutput
# @vicinae.icon ✳️
# @vicinae.keywords ["claude","usage","limits","quota","rate limit","anthropic","tokens left"]
# @vicinae.packageName Claude
# Same endpoint + token as the claude-usage@scottnelson top-bar extension.
import json, os, sys, urllib.request, datetime
tok = json.load(open(os.path.expanduser('~/.claude/.credentials.json')))['claudeAiOauth']['accessToken']
req = urllib.request.Request('https://api.anthropic.com/api/oauth/usage',
    headers={'Authorization': f'Bearer {tok}', 'anthropic-beta': 'oauth-2025-04-20', 'Accept': 'application/json'})
try:
    d = json.load(urllib.request.urlopen(req, timeout=10))
except Exception as e:
    sys.exit(f'usage fetch failed: {e}  (run `claude` to refresh the token)')
def bar(p): n = round(p / 5); return '█' * n + '░' * (20 - n)
def when(iso):
    if not iso: return ''
    t = datetime.datetime.fromisoformat(iso.replace('Z', '+00:00')).astimezone()
    left = t - datetime.datetime.now(t.tzinfo); h, m = divmod(int(left.total_seconds() // 60), 60)
    return f'resets in {h}h{m:02d}m ({t:%a %-I:%M %p})'
rows = [('Session (5h)', d.get('five_hour')), ('Weekly (all)', d.get('seven_day')),
        ('Weekly Opus', d.get('seven_day_opus')), ('Weekly Sonnet', d.get('seven_day_sonnet'))]
for k, v in d.items():
    if k.startswith('seven_day_') and k not in ('seven_day_opus', 'seven_day_sonnet') and isinstance(v, dict):
        rows.append((f'Weekly {k[10:].title()}', v))
for name, v in rows:
    if v: print(f'{name:<14} {bar(v["utilization"])} {v["utilization"]:5.1f}%   {when(v.get("resets_at"))}')
