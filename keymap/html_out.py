"""HTML renderer for keymap.py rows."""
import html, re

CATS = [
  ("Tabs & browsing", r"tab|close|history|back|forward|address|reload|zoom|link|autofill|1password"),
  ("Editing", r"copy|paste|cut|undo|redo|select all|find|save|print|\bnew\b|palette|kill to"),
  ("Text navigation", r"line|word|doc|select to|home|end"),
  ("Windows & tiling", r"tile|tiling|maximi|monitor|move window|close$|quit|hide|show desktop|switch|workspace|center|half|corner|screen"),
  ("System", r"screenshot|lock|clipboard|dictation|vicinae|keybindings|launcher|screensaver|record|wallpaper"),
]
def cat(r):
    t = (r["action"] + " " + r["chord"]).lower()
    for name, rx in CATS:
        if re.search(rx, t): return name
    return "Other"

def kbd(chord):
    parts = chord.split("+")
    return "".join(f"<kbd>{html.escape(p)}</kbd>" for p in parts)

def row_html(r):
    becomes = f'<span class="becomes">⇒ {html.escape(r["becomes"])}</span>' if r["becomes"] and r["becomes"] != r["action"] else ""
    warn = ' class="warn"' if "⚠" in r["action"] else ""
    return (f'<div class="row"{warn} data-s="{html.escape((r["chord"]+" "+r["action"]+" "+r["becomes"]+" "+r["owner"]).lower())}">'
            f'<div class="chord">{kbd(r["chord"])}</div>'
            f'<div class="act">{html.escape(r["action"])} {becomes}</div>'
            f'<div class="own">{html.escape(r["owner"])}</div></div>')

def section(title, rows, sub=""):
    if not rows: return ""
    return (f'<section><h2>{html.escape(title)} <small>{len(rows)}</small><span class="sub">{html.escape(sub)}</span></h2>'
            + "".join(row_html(r) for r in rows) + "</section>")

def render(rows, probs, focused):
    appname = {"*tyxis*": "Terminal (Ptyxis)", "*hrome*": "Chrome", "*irefox*": "Firefox"}
    glob_ = [r for r in rows if r["app"] is None and r["owner"] == "keyd global" and "+" in r["chord"]]
    base  = [r for r in rows if r["app"] is None and r["owner"] == "keyd global" and "+" not in r["chord"]]
    gnome_user = [r for r in rows if r["app"] is None and r["owner"] != "keyd global" and "★" in r["owner"]]
    gnome_def  = [r for r in rows if r["app"] is None and r["owner"] != "keyd global" and "★" not in r["owner"]]
    out = []
    # Cmd layer by category
    bycat = {}
    for r in glob_: bycat.setdefault(cat(r), []).append(r)
    for name, _ in CATS + [("Other", "")]:
        rs = sorted(bycat.get(name, []), key=lambda r: (len(r["chord"].split("+")), r["chord"]))
        out.append(section(name, rs, "keyd global · works everywhere unless an app section below overrides it"))
    cmd_html = "".join(out)
    apps_html = ""
    for pat, nm in appname.items():
        rs = [r for r in rows if r["app"] == pat]
        apps_html += section(nm + (" · focused" if focused and __import__("fnmatch").fnmatch(focused, pat) else ""), rs, "overrides the Cmd layer only while this app is focused")
    gnome_html = section("GNOME, Tiling Shell & custom (set by you)", gnome_user, "dconf / gsettings · these reach GNOME only if keyd doesn't eat the chord first")
    gnome_html += section("Physical key swaps & special keys", base, "keyd [main]")
    gnome_html += f'<details><summary>GNOME defaults left untouched ({len(gnome_def)})</summary>{section("GNOME defaults", gnome_def)}</details>'
    hb = ('<div class="health ok">✅ keyd running · app-mapper alive · GNOME extension on · configs match fedora-bootstrap · no shadowed bindings</div>'
          if not probs else '<div class="health bad">🔴 ' + " &nbsp;·&nbsp; ".join(html.escape(p) for p in probs) + "</div>")
    return f"""<!doctype html><meta charset=utf-8><title>Keymap</title>
<style>
:root{{--bg:#101318;--card:#171b22;--fg:#e6e6e6;--dim:#8b93a1;--acc:#7aa2f7;--warn:#f7768e;--kbd:#242a35}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--fg);font:17px/1.4 -apple-system,Inter,system-ui,sans-serif}}
header{{position:sticky;top:0;background:var(--bg);padding:18px 32px 12px;border-bottom:1px solid #222;z-index:2;display:flex;gap:24px;align-items:center;flex-wrap:wrap}}
h1{{margin:0;font-size:26px}}h1 span{{color:var(--dim);font-weight:400;font-size:16px;margin-left:12px}}
input{{flex:1;min-width:320px;font:inherit;font-size:19px;padding:10px 14px;border-radius:10px;border:1px solid #333;background:#0b0d11;color:var(--fg)}}
.health{{width:100%;padding:8px 12px;border-radius:8px;font-size:15px}}.ok{{background:#12281c;color:#9ece6a}}.bad{{background:#3a1a22;color:#f7768e}}
main{{columns:3 520px;column-gap:28px;padding:20px 32px 60px}}
section{{break-inside:avoid;background:var(--card);border-radius:14px;padding:14px 18px;margin:0 0 22px}}
h2{{margin:0 0 8px;font-size:18px;color:var(--acc)}}h2 small{{color:var(--dim);font-weight:400;margin-left:6px}}
.sub{{display:block;color:var(--dim);font-size:13px;font-weight:400;margin-top:2px}}
.row{{display:grid;grid-template-columns:230px 1fr auto;gap:10px;align-items:center;padding:6px 0;border-top:1px solid #222}}
.row.warn .act{{color:var(--warn)}}.row.hide{{display:none}}
kbd{{display:inline-block;background:var(--kbd);border:1px solid #333;border-bottom-width:3px;border-radius:6px;padding:1px 8px;margin-right:4px;font:600 14px ui-monospace,monospace;color:#fff}}
.act{{font-size:15px}}.becomes{{color:var(--dim);font-size:13px;margin-left:8px;font-family:ui-monospace,monospace}}
.own{{color:var(--dim);font-size:12px;white-space:nowrap}}
details{{break-inside:avoid;color:var(--dim)}}summary{{cursor:pointer;padding:8px 0}}details section{{margin-top:10px}}
footer{{position:fixed;bottom:0;right:0;padding:6px 14px;color:var(--dim);font-size:12px;background:var(--bg)}}
</style>
<header><h1>Keybindings <span>read live from keyd, dconf, extensions</span></h1>
<input id=q placeholder="Filter: close, tab, ctrl+w, tiling, chrome…" autofocus>{hb}</header>
<main>{cmd_html}{apps_html}{gnome_html}</main>
<footer>Cmd+W closes · type to filter · Esc clears</footer>
<script>
const q=document.getElementById('q'),rows=[...document.querySelectorAll('.row')],secs=[...document.querySelectorAll('section')];
function f(){{const v=q.value.toLowerCase().trim().split(/\\s+/).filter(Boolean);
rows.forEach(r=>{{const s=r.dataset.s;r.classList.toggle('hide',!v.every(t=>s.includes(t)))}});
secs.forEach(s=>s.style.display=s.querySelector('.row:not(.hide)')?'':'none');
document.querySelectorAll('details').forEach(d=>{{if(v.length)d.open=true}});}}
q.addEventListener('input',f);document.addEventListener('keydown',e=>{{if(e.key==='Escape'){{q.value='';f()}}if(e.key.length===1&&document.activeElement!==q){{q.focus()}}}});
</script>"""
