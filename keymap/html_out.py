"""HTML renderer for keymap.py rows.

Design goal (Aug 28 2026): one screen at 4K, no scrolling. So:
  * numbered / arrow families collapse into one row (Cmd+1…9, Cmd+←→↑↓),
  * the standard Mac editing chords (Cmd+C/V/X/Z/A/S/F/P/N/W/R/L, zoom) become ONE line,
  * keyd pass-through rows ("→ GNOME …") are dropped when the real GNOME/extension row exists,
  * identical browser sections merge,
  * GNOME defaults and in-popup keys only appear while filtering.
Every collapsed row keeps the full expansion in data-s so the filter still finds "tab 3".
"""
import html, re, fnmatch

ARROWS = {"←": "left", "→": "right", "↑": "up", "↓": "down"}
STD = {  # chord -> short label; these are what every Mac user assumes, one line is enough
    "Cmd+C": "copy", "Cmd+V": "paste", "Cmd+X": "cut", "Cmd+Z": "undo", "Cmd+Shift+Z": "redo",
    "Cmd+A": "select all", "Cmd+S": "save", "Cmd+F": "find", "Cmd+P": "print", "Cmd+N": "new",
    "Cmd+W": "close tab", "Cmd+R": "reload", "Cmd+L": "address bar", "Cmd+=": "zoom in",
    "Cmd+Shift+=": "zoom in", "Cmd+-": "zoom out", "Cmd+0": "zoom reset", "Cmd+Click": "open link in new tab",
}
# What Scott actually forgets: pinned to the top, in this order. (chord-regex, owner-substring or None)
PINNED = [
    (r"^Cmd\+Space$", None), (r"^Cmd\+Shift\+C$", "Copyous"), (r"^Cmd\+/$", None),
    (r"^Shift\+Cmd\+3$", "GNOME shell"), (r"^Shift\+Cmd\+4$", "GNOME shell"),
    (r"^Ctrl$", "keyd"), (r"^Cmd\+Q$", "GNOME wm"), (r"^Cmd\+Esc$", "GNOME media"), (r"^Opt\+Cmd\+Esc$", None),
    (r"^Cmd\+K$", None), (r"^Cmd\+Backslash$", None), (r"^Cmd\+T$", "keyd global"),
    (r"^Cmd\+Y$", None), (r"^Cmd\+\[$", None), (r"^Cmd\+\]$", None),
    (r"^Ctrl\+Cmd\+Opt\+[←→↑↓]$", "Tiling"), (r"^Ctrl\+Cmd\+Opt\+[,.]$", None), (r"^Ctrl\+Cmd\+Opt\+H$", None),
    (r"^Ctrl\+Opt\+Cmd\+M$", None), (r"^Cmd\+Shift\+[←→]$", "*tyxis*"), (r"^Cmd\+Tab$", None),
]

def norm(c):
    parts = c.split("+"); mods = sorted(parts[:-1], key=lambda m: {"Ctrl": 0, "Cmd": 1, "Opt": 2, "Shift": 3}.get(m, 9))
    return "+".join(mods + parts[-1:])

def kbd(chord):
    return "".join(f"<kbd>{html.escape(p)}</kbd>" for p in chord.split("+"))

def row_html(r):
    becomes = f'<span class="b">⇒ {html.escape(r["becomes"])}</span>' if r.get("becomes") and r["becomes"] != r["action"] else ""
    cls = "row" + (" warn" if "⚠" in r["action"] else "")
    s = (r["chord"] + " " + r["action"] + " " + (r.get("becomes") or "") + " " + r["owner"] + " " + (r.get("search") or "")).lower()
    return (f'<div class="{cls}" data-s="{html.escape(s)}"><div class="c">{kbd(r["chord"])}</div>'
            f'<div class="a">{html.escape(r["action"])} {becomes}</div><div class="o">{html.escape(r["owner"])}</div></div>')

def section(title, rows, sub="", extra_cls=""):
    if not rows: return ""
    return (f'<section class="{extra_cls}"><h2>{html.escape(title)} <small>{len(rows)}</small>'
            f'{"<span class=sub>" + html.escape(sub) + "</span>" if sub else ""}</h2>' + "".join(row_html(r) for r in rows) + "</section>")

# ---------- collapsing --------------------------------------------------------
def collapse_numbers(rows):
    """Cmd+1..Cmd+9 'tab 1'..'tab 9' -> one row Cmd+1…9 'tab 1–9'."""
    groups, out = {}, []
    for r in rows:
        m = re.fullmatch(r"(.*\+)(\d)", r["chord"]); ma = re.fullmatch(r"(.*?)\s*(\d)", r["action"])
        if m and ma and m.group(2) == ma.group(2):
            groups.setdefault((m.group(1), ma.group(1), r["owner"], r.get("app")), []).append(r)
        else: out.append(r)
    for (pre, act, owner, app), rs in groups.items():
        if len(rs) < 3: out.extend(rs); continue
        ns = sorted(int(r["chord"][-1]) for r in rs)
        out.append(dict(chord=f"{pre}{ns[0]}…{ns[-1]}", action=f"{act} {ns[0]}–{ns[-1]}", becomes=rs[0]["becomes"][:-1] + "N" if rs[0]["becomes"] else "",
                        owner=owner, app=app, search=" ".join(r["chord"] + " " + r["action"] for r in rs)))
    return out

def collapse_arrows(rows):
    """Cmd+←/→/↑/↓ with four actions -> one row 'Cmd+←→↑↓  line start · line end · doc top · doc bottom'."""
    groups, out = {}, []
    for r in rows:
        m = re.fullmatch(r"(.*\+)([←→↑↓])", r["chord"])
        if m: groups.setdefault((m.group(1), r["owner"], r.get("app")), []).append(r)
        else: out.append(r)
    for (pre, owner, app), rs in groups.items():
        if len(rs) < 2: out.extend(rs); continue
        rs.sort(key=lambda r: "←→↑↓".index(r["chord"][-1]))
        acts = [r["action"].split("  ⚠")[0].split("  (")[0] for r in rs]
        # "move window left/up/right/down" -> "move window ← ↑ → ↓"
        common = acts[0]
        for d in ARROWS.values(): common = re.sub(rf"\b{d}\b", "", common)
        common = re.sub(r"\s+", " ", common).strip()
        same_stem = all(re.sub(r"\b(left|right|up|down)\b", "", a).strip() == common for a in acts)
        action = common + " " + "".join(r["chord"][-1] for r in rs) if same_stem and common else " · ".join(acts)
        out.append(dict(chord=pre + "".join(r["chord"][-1] for r in rs), action=action, becomes="",
                        owner=owner, app=app, search=" ".join(r["chord"] + " " + r["action"] + " " + ARROWS[r["chord"][-1]] for r in rs)))
    return out

def fold_standard(rows):
    std = [r for r in rows if r["owner"] == "keyd global" and r["chord"] in STD]
    rest = [r for r in rows if r not in std]
    if not std: return rest, None
    labels = " ".join(f"{r['chord'].replace('Cmd+', '⌘')}" for r in sorted(std, key=lambda r: list(STD).index(r["chord"])))
    one = dict(chord="Cmd+C V X Z A S F P N W R L …", action="standard Mac chords → the Ctrl equivalent, everywhere",
               becomes=labels, owner="keyd global", app=None,
               search=" ".join(r["chord"] + " " + r["action"] + " " + (r["becomes"] or "") for r in std))
    return rest, one

# ---------- render --------------------------------------------------------------
def render(rows, probs, focused):
    rows = [dict(r) for r in rows]
    # 1. drop keyd pass-through rows when the real owner row exists for the same chord
    real = {norm(r["chord"]) for r in rows if r["owner"] != "keyd global" and r.get("app") is None}
    rows = [r for r in rows if not (r["owner"] == "keyd global" and r["action"].startswith("→") and norm(r["chord"]) in real)]
    # 2. drop obvious noise
    rows = [r for r in rows if r["chord"] not in ("Alt", "Super", "dtap+Ctrl") and not r["action"].startswith("Cmd+K:")]
    for r in rows:
        if r["chord"] == "Ctrl": r["action"] = "double-tap Ctrl = dictation (hold = normal Ctrl)"; r["becomes"] = ""; r["chord"] = "Ctrl Ctrl"
        if r["chord"] == "Cmd+Backslash": r["chord"] = "Cmd+\\"; r["action"] = "1Password autofill"
        if r["chord"] == "Cmd+K": r["action"] = "Obsidian / app palette (passes Ctrl+K)"
        r["action"] = re.sub(r"\s*shortcut$", "", r["action"])
        if r["owner"] == "GNOME wm ★" and r["chord"] == "Cmd+Q": r["action"] = "quit app"
        if r["owner"] == "GNOME media ★" and r["chord"] == "Cmd+Esc": r["action"] = "lock screen"
        if r["chord"] == "Cmd+/": r["action"] = "this keybindings page"
        if r.get("becomes", "").startswith("/"): r["becomes"] = ""
    # 3. pinned "daily drivers"
    pinned, seen = [], set()
    for rx, own in PINNED:
        for r in rows:
            if id(r) in seen: continue
            if re.search(rx, r["chord"]) and (own is None or own in r["owner"] or own == r.get("app")):
                pinned.append(r); seen.add(id(r))
    dd = {}
    for r in pinned: dd.setdefault((r["chord"], r["action"]), r)      # Firefox+Chrome twins -> one row
    pinned = collapse_arrows(list(dd.values()))
    rest = [r for r in rows if id(r) not in seen]
    # 4. buckets
    glob_ = [r for r in rest if r.get("app") is None and r["owner"] == "keyd global"]
    glob_, std_line = fold_standard(glob_)
    glob_ = collapse_arrows(collapse_numbers(glob_))
    user_gnome = collapse_arrows([r for r in rest if r.get("app") is None and r["owner"] != "keyd global" and "★" in r["owner"]])
    defaults = collapse_arrows([r for r in rest if r.get("app") is None and r["owner"] != "keyd global" and "★" not in r["owner"]])
    term = collapse_arrows([r for r in rest if r.get("app") == "*tyxis*" and not r["owner"].startswith("Ptyxis")])
    ptyxis_side = [r for r in rest if r.get("app") == "*tyxis*" and r["owner"].startswith("Ptyxis")]   # implementation half of keyd rows
    ff = [r for r in rest if r.get("app") == "*irefox*"]; ch = [r for r in rest if r.get("app") == "*hrome*"]
    popup = [r for r in rest if r.get("app") and r["app"].startswith("inside")]
    key = lambda rs: sorted((r["chord"], r["action"]) for r in rs)
    if key(ff) == key(ch): browsers = [("Browsers · Firefox & Chrome", ff)]
    else: browsers = [("Firefox", ff), ("Chrome", ch)]
    order = lambda rs: sorted(rs, key=lambda r: (len(r["chord"].split("+")), r["chord"]))
    foc = lambda pat: " · focused" if focused and fnmatch.fnmatch(focused, pat) else ""

    main = section("Daily drivers", pinned, "the ones you actually forget", "pin")
    main += section("Cmd layer (keyd, everywhere)", ([std_line] if std_line else []) + order(glob_), "Mac chords → Linux equivalents")
    main += section("Terminal (Ptyxis)" + foc("*tyxis*"), order(term), "overrides the Cmd layer while focused")
    for nm, rs in browsers: main += section(nm + foc("*irefox*"), order(rs), "overrides the Cmd layer while focused")
    main += section("GNOME · Tiling Shell · extensions (set by you)", order(user_gnome), "★ = user-set in dconf")
    more = section("Inside the Copyous popup", order(popup)) + section("Ptyxis-side shortcuts (what keyd sends)", order(ptyxis_side)) + section("GNOME defaults left untouched", order(defaults))
    hb = ('<div class="health ok">✅ keyd · app-mapper · GNOME extension · configs match fedora-bootstrap · no shadowed bindings</div>'
          if not probs else '<div class="health bad">🔴 ' + " &nbsp;·&nbsp; ".join(html.escape(p) for p in probs) + "</div>")
    return f"""<!doctype html><meta charset=utf-8><title>Keymap</title>
<style>
:root{{--bg:rgba(14,17,22,.88);--card:rgba(255,255,255,.045);--fg:#e6e6e6;--dim:#8b93a1;--acc:#7aa2f7;--warn:#f7768e;--kbd:#242a35}}
*{{box-sizing:border-box}}html,body{{height:100%}}body{{margin:0;background:var(--bg);color:var(--fg);font:16px/1.4 -apple-system,Inter,system-ui,sans-serif;overflow-x:hidden}}
header{{padding:12px 22px 6px;display:flex;gap:16px;align-items:center;flex-wrap:wrap}}
h1{{margin:0;font-size:22px}}h1 span{{color:var(--dim);font-weight:400;font-size:13px;margin-left:10px}}
input{{flex:1;min-width:280px;max-width:640px;font:inherit;font-size:16px;padding:6px 12px;border-radius:8px;border:1px solid #333;background:#0b0d11;color:var(--fg)}}
.health{{padding:4px 10px;border-radius:6px;font-size:12px}}.ok{{background:#12281c;color:#9ece6a}}.bad{{background:#3a1a22;color:#f7768e}}
main{{columns:3 600px;column-gap:16px;padding:6px 22px 30px}}
section{{break-inside:avoid;background:var(--card);border-radius:10px;padding:8px 12px;margin:0 0 12px}}
section.pin{{outline:1px solid rgba(122,162,247,.35)}}
h2{{margin:0 0 4px;font-size:16px;color:var(--acc)}}h2 small{{color:var(--dim);font-weight:400;margin-left:5px}}
.sub{{display:block;color:var(--dim);font-size:11px;font-weight:400}}
.row{{display:grid;grid-template-columns:minmax(150px,auto) 1fr auto;gap:8px;align-items:center;padding:4px 0;border-top:1px solid rgba(255,255,255,.05)}}
.row.warn .a{{color:var(--warn)}}.row.hide{{display:none}}
kbd{{display:inline-block;background:var(--kbd);border:1px solid #3a4150;border-bottom-width:2px;border-radius:5px;padding:0 6px;margin-right:3px;font:600 13px ui-monospace,monospace;color:#fff;line-height:20px}}
.a{{font-size:15px}}.b{{color:var(--dim);font-size:11px;margin-left:6px;font-family:ui-monospace,monospace}}
.o{{color:var(--dim);font-size:11px;white-space:nowrap}}
#more{{display:none}}body.q #more{{display:block}}
footer{{position:fixed;bottom:0;right:0;padding:4px 12px;color:var(--dim);font-size:11px;background:var(--bg)}}
</style>
<header><h1>Keybindings <span>live from keyd · dconf · extensions</span></h1>
<input id=q placeholder="Filter: tab 3, tiling, chrome, screenshot…" autofocus>{hb}</header>
<main>{main}<div id=more>{more}</div></main>
<footer>Cmd+/ or Esc closes · type to filter · filtering also searches GNOME defaults</footer>
<script>
const q=document.getElementById('q'),rows=[...document.querySelectorAll('.row')],secs=[...document.querySelectorAll('section')];
function f(){{const v=q.value.toLowerCase().trim().split(/\\s+/).filter(Boolean);document.body.classList.toggle('q',v.length>0);
rows.forEach(r=>{{const s=r.dataset.s;r.classList.toggle('hide',!v.every(t=>s.includes(t)))}});
secs.forEach(s=>s.style.display=s.querySelector('.row:not(.hide)')?'':'none');}}
q.addEventListener('input',f);document.addEventListener('keydown',e=>{{if(e.key.length===1&&document.activeElement!==q){{q.focus()}}}});
</script>"""
