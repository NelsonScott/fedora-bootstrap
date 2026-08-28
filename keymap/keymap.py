#!/usr/bin/env python3
"""keymap: one view of every keybinding on this PC, read LIVE from where each
binding actually lives (not from the git repo):

  /etc/keyd/default.conf          keyd global ("Cmd" layer etc.)
  ~/.config/keyd/app.conf         keyd per-app (Ptyxis, Chrome, Firefox)
  dconf (gsettings)               GNOME wm/shell/mutter/media-keys + custom
  Tiling Shell extension schema   tiling keys
  dconf /org/gnome/Ptyxis         terminal-internal shortcuts

Usage: keymap.py [--format dmenu|table|json] [--app CLASS] [--health]
"""
import json, os, re, subprocess, sys, glob

HOME = os.path.expanduser("~")
REPO = f"{HOME}/fedora-bootstrap/keyd"

# ---------- helpers ---------------------------------------------------------
KEYNAMES = {
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "equal": "=", "minus": "-", "leftbrace": "[", "rightbrace": "]",
    "comma": ",", "period": ".", "slash": "/", "backspace": "Backspace",
    "leftmouse": "Click", "leftcontrol": "Ctrl", "leftmeta": "Super",
    "leftalt": "Alt", "home": "Home", "end": "End", "pageup": "PgUp",
    "pagedown": "PgDn", "escape": "Esc", "space": "Space", "tab": "Tab",
    "print": "Print", "return": "Enter",
}
MODS = {"C": "Ctrl", "S": "Shift", "A": "Alt", "M": "Super", "G": "AltGr"}
LAYER_LABEL = {"meta": "Cmd", "shift": "Shift", "alt": "Opt", "control": "Ctrl"}

def keyname(k):
    k = k.strip()
    return KEYNAMES.get(k, k.upper() if len(k) == 1 else k.capitalize())

def keyd_action_human(a):
    """C-S-w -> Ctrl+Shift+W ; home -> Home ; command(x) -> run x"""
    a = a.strip()
    m = re.match(r"command\((.*)\)", a)
    if m: return f"run {m.group(1)}"
    m = re.match(r"overload\((\w+),\s*(.*)\)", a)
    if m: return f"hold={m.group(1).capitalize()} tap→{m.group(2)}"
    parts = a.split("-")
    mods = [MODS[p] for p in parts[:-1] if p in MODS]
    return "+".join(mods + [keyname(parts[-1])])

def layer_chord(layer, key):
    mods = [LAYER_LABEL.get(m, m) for m in layer.split("+")]
    return "+".join(mods + [keyname(key)])

# Meaning of common OUTPUT chords when the config has no comment for a line.
MEANING = {
    "Ctrl+C": "copy", "Ctrl+V": "paste", "Ctrl+X": "cut", "Ctrl+Z": "undo",
    "Ctrl+S": "save", "Ctrl+F": "find", "Ctrl+N": "new", "Ctrl+R": "reload",
    "Ctrl+P": "print", "Ctrl+A": "select all", "Ctrl+W": "close tab",
    "Ctrl+T": "new tab", "Ctrl+Shift+T": "new tab (terminal) / reopen tab (browser)",
    "Ctrl+L": "address bar", "Ctrl+H": "history", "Ctrl+=": "zoom in",
    "Ctrl+-": "zoom out", "Ctrl+0": "zoom reset", "Home": "line start",
    "End": "line end", "Ctrl+Home": "doc top", "Ctrl+End": "doc bottom",
    "Shift+Home": "select to line start", "Shift+End": "select to line end",
    "Ctrl+Shift+Home": "select to doc top", "Ctrl+Shift+End": "select to doc bottom",
    "Ctrl+Shift+Z": "redo", "Ctrl+PgUp": "previous tab", "Ctrl+PgDn": "next tab",
    "Ctrl+←": "word left", "Ctrl+→": "word right", "Ctrl+Backspace": "delete word",
    "Alt+←": "back", "Alt+→": "forward", "Ctrl+Click": "open link in new tab",
    "Ctrl+Shift+C": "copy (terminal)", "Ctrl+Shift+V": "paste (terminal)",
    "Ctrl+Shift+W": "close tab (terminal)", "Ctrl+Shift+A": "select all (terminal)",
    "Ctrl+Shift+N": "new window (terminal)", "Ctrl+U": "kill to line start",
    "Ctrl+/": "undo (shell)", "Super+Q": "→ GNOME quit", "Super+Shift+3": "→ GNOME screenshot",
    "Super+Shift+4": "→ GNOME screenshot region", "Super+Shift+C": "→ GNOME clipboard history",
    "Alt+Backspace": "delete word (shell)", "Alt+Left": "word left (shell)",
    "Ctrl+Alt+Super+←": "→ tiling (protected)", "Ctrl+Alt+Super+→": "→ tiling (protected)",
}
for i in range(1, 10): MEANING[f"Ctrl+{i}"] = f"tab {i}"

# ---------- keyd ------------------------------------------------------------
def parse_keyd_file(path, per_app=False):
    rows, section, comment = [], None, []
    try:
        text = open(path).read()
    except PermissionError:
        text = subprocess.run(["sudo", "-n", "cat", path], capture_output=True, text=True).stdout
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            comment = []; continue
        if line.startswith("#"):
            comment.append(line.lstrip("# ").strip()); continue
        if line.startswith("["):
            section = line.strip("[]").split(":")[0]; comment = []; continue
        if "=" not in line: continue
        k, v = [s.strip() for s in line.split("=", 1)]
        if section in ("ids", "global"): continue
        if per_app:
            app = section
            layer, key = k.rsplit(".", 1) if "." in k else ("main", k)
        else:
            app = None
            layer, key = section, k
        out = keyd_action_human(v)
        desc = MEANING.get(out) or (re.split(r"(?<=[.:;])\s", " ".join(comment), maxsplit=1)[0][:70] if comment else "")
        if layer == "main":
            chord = keyname(key)
        else:
            chord = layer_chord(layer, key)
        rows.append(dict(chord=chord, action=desc or out, becomes=out,
                         owner="keyd app" if per_app else "keyd global",
                         app=app, src=os.path.basename(path)))
        comment = []
    return rows

APPNAME = {"*tyxis*": "Terminal", "*irefox*": "Firefox", "*hrome*": "Chrome"}

# ---------- dconf / gsettings ----------------------------------------------
def gs(schema, extra=()):
    out = subprocess.run(["gsettings", *extra, "list-recursively", schema],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3: yield parts[1], parts[2]

def accel_human(a):
    a = a.replace("<Control>", "Ctrl+").replace("<Ctrl>", "Ctrl+").replace("<Primary>", "Ctrl+")
    a = a.replace("<Super>", "Cmd+").replace("<Shift>", "Shift+").replace("<Alt>", "Opt+")
    a = re.sub(r"<([^>]+)>", lambda m: m.group(1) + "+", a)
    tail = a.split("+")[-1]
    return "+".join(a.split("+")[:-1] + [keyname(tail.lower()) if len(tail) > 1 and tail.lower() in KEYNAMES else (tail.upper() if len(tail)==1 else tail)])

def user_set(path):
    return subprocess.run(["dconf", "read", path], capture_output=True, text=True).stdout.strip() != ""

def gnome_rows():
    rows = []
    schemas = [
        ("org.gnome.desktop.wm.keybindings", "/org/gnome/desktop/wm/keybindings/", "GNOME wm", ()),
        ("org.gnome.shell.keybindings", "/org/gnome/shell/keybindings/", "GNOME shell", ()),
        ("org.gnome.mutter.keybindings", "/org/gnome/mutter/keybindings/", "GNOME mutter", ()),
        ("org.gnome.mutter.wayland.keybindings", "/org/gnome/mutter/wayland/keybindings/", "GNOME mutter", ()),
        ("org.gnome.settings-daemon.plugins.media-keys", "/org/gnome/settings-daemon/plugins/media-keys/", "GNOME media", ()),
    ]
    ts = glob.glob(f"{HOME}/.local/share/gnome-shell/extensions/tilingshell@*/schemas")
    if ts:
        schemas.append(("org.gnome.shell.extensions.tilingshell", "/org/gnome/shell/extensions/tilingshell/", "Tiling Shell", ("--schemadir", ts[0])))
    for schema, path, owner, extra in schemas:
        for key, val in gs(schema, extra):
            if not val.startswith("[") or val in ("[]", "@as []") or key in ("selected-layouts",): continue
            accels = re.findall(r"'([^']+)'", val)
            if not accels: continue
            star = user_set(path + key)
            for acc in accels:
                rows.append(dict(chord=accel_human(acc), action=key.replace("-", " "),
                                 becomes="", owner=owner + (" ★" if star else ""), app=None, src=schema))
    # custom keybindings
    for p in subprocess.run(["dconf", "list", "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"],
                            capture_output=True, text=True).stdout.split():
        base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/" + p
        rd = lambda k: subprocess.run(["dconf", "read", base + k], capture_output=True, text=True).stdout.strip().strip("'")
        if rd("binding"):
            rows.append(dict(chord=accel_human(rd("binding")), action=rd("name"), becomes=rd("command"),
                             owner="GNOME custom ★", app=None, src="custom-keybindings"))
    # Ptyxis (only user-set)
    out = subprocess.run(["dconf", "dump", "/org/gnome/Ptyxis/Shortcuts/"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if "=" in line and not line.startswith("["):
            k, v = line.split("=", 1)
            rows.append(dict(chord=accel_human(v.strip().strip("'")), action=k.replace("-", " "),
                             becomes="", owner="Ptyxis ★", app="*tyxis*", src="org.gnome.Ptyxis"))
    return rows

# ---------- health ----------------------------------------------------------
def health():
    probs = []
    if subprocess.run(["systemctl", "is-active", "keyd"], capture_output=True, text=True).stdout.strip() != "active":
        probs.append("keyd service DOWN")
    mapper = None
    for p in glob.glob("/proc/[0-9]*/cmdline"):
        try:
            if b"keyd-application-mapper" in open(p, "rb").read() and b"python3" in open(p, "rb").read():
                mapper = p.split("/")[2]
        except Exception: pass
    if not mapper: probs.append("app-mapper NOT RUNNING (per-app binds frozen)")
    elif not any("keyd.fifo" in os.readlink(f) for f in glob.glob(f"/proc/{mapper}/fd/*") if os.path.islink(f)):
        probs.append("app-mapper not reading keyd.fifo")
    if subprocess.run(["gsettings", "get", "org.gnome.shell", "disable-user-extensions"], capture_output=True, text=True).stdout.strip() == "true":
        probs.append("GNOME extensions DISABLED (safe mode)")
    en = subprocess.run(["gnome-extensions", "list", "--enabled"], capture_output=True, text=True).stdout
    if "keyd@" not in en: probs.append("keyd GNOME extension not enabled")
    if "keyd" not in subprocess.run(["id", "-nG"], capture_output=True, text=True).stdout.split():
        probs.append("user not in keyd group")
    for live, repo in ((f"{HOME}/.config/keyd/app.conf", f"{REPO}/app.conf"), ("/etc/keyd/default.conf", f"{REPO}/default.conf")):
        if os.path.exists(repo) and subprocess.run(["diff", "-q", live, repo], capture_output=True).returncode != 0:
            probs.append(f"{os.path.basename(live)} differs from fedora-bootstrap")
    return probs

# ---------- focused app -----------------------------------------------------
def focused_class():
    r = subprocess.run(["gdbus", "call", "--session", "--dest", "org.gnome.Shell", "--object-path",
                        "/org/scottnelson/DesktopActions", "--method", "org.scottnelson.DesktopActions.FocusedWindow"],
                       capture_output=True, text=True, timeout=2)
    return r.stdout.lower()

def app_matches(pattern, cls):
    from fnmatch import fnmatch
    return bool(cls) and fnmatch(cls, pattern)

# ---------- main ------------------------------------------------------------
def main():
    fmt = "dmenu"; app = None; want_health = False
    args = sys.argv[1:]
    while args:
        a = args.pop(0)
        if a == "--format": fmt = args.pop(0)
        elif a == "--app": app = args.pop(0)
        elif a == "--health": want_health = True
    rows = parse_keyd_file("/etc/keyd/default.conf") + parse_keyd_file(f"{HOME}/.config/keyd/app.conf", per_app=True) + gnome_rows()
    if app is None:
        try: app = focused_class()
        except Exception: app = ""
    # per-app override shadows global for same chord
    def rank(r):
        if r["app"] and app_matches(r["app"], app): return 0
        if r["app"] is None: return 1
        return 2
    NOISE = re.compile(r"XF86|^Ctrl\+Opt\+F\d|^/org/|^,$|^Print$")
    rows = [r for r in rows if not NOISE.search(r["chord"])]
    def owner_rank(r):
        o = r["owner"]
        if o.startswith("keyd"): return 0
        if "★" in o or "Tiling" in o: return 1
        return 2
    rows.sort(key=lambda r: (rank(r), owner_rank(r), r["owner"], r["chord"]))
    probs = health() if want_health or fmt in ("dmenu", "html") else []
    def normchord(c):
        parts = c.split("+"); mods = sorted(parts[:-1], key=lambda m: {"Ctrl":0,"Cmd":1,"Opt":2,"Shift":3}.get(m, 9))
        return "+".join(mods + parts[-1:])
    eaten = {normchord(r["chord"]): r["becomes"] for r in rows if r["owner"] == "keyd global" and "Cmd" in r["chord"]}
    for r in rows:
        if r["owner"].startswith(("GNOME", "Tiling")):
            b = eaten.get(normchord(r["chord"]))
            if b and "Super" not in b:
                if "★" in r["owner"]:
                    r["action"] += f"  ⚠ UNREACHABLE: keyd turns it into {b}"
                    probs.append(f"{r['chord']} ({r['action'].split('  ⚠')[0]}) shadowed by keyd")
                else:
                    r["action"] += f"  (GNOME default, overridden by keyd → {b})"
    if fmt == "html":
        from html_out import render
        print(render(rows, probs, app)); return
    if fmt == "json":
        print(json.dumps(dict(health=probs, focused=app, rows=rows), indent=1)); return
    hdr = ("✅ keyd OK · mapper alive · confs match repo" if not probs else "🔴 " + " · ".join(probs))
    lines = [hdr] if fmt == "dmenu" else []
    for r in rows:
        where = APPNAME.get(r["app"], r["app"]) if r["app"] else "everywhere"
        if r["app"] and app_matches(r["app"], app): where += " (focused)"
        becomes = f"  ⇒ {r['becomes']}" if r["becomes"] and r["becomes"] != r["action"] else ""
        if fmt == "table":
            lines.append(f"{r['chord']:<24} {r['action'][:44]:<44} {r['becomes'][:22]:<22} {r['owner']:<16} {where}")
        else:
            lines.append(f"{r['chord']}   →   {r['action']}{becomes}   ·   {r['owner']}   ·   {where}")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
