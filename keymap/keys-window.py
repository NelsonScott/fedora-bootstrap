#!/usr/bin/env python3
"""Native viewer for the keymap page: undecorated, translucent, maximized.
Esc closes it. Running it again while open closes it (so Cmd+/ toggles)."""
import os, signal, sys
import gi
gi.require_version("Gtk", "4.0"); gi.require_version("WebKit", "6.0"); gi.require_version("Gdk", "4.0")
from gi.repository import Gtk, WebKit, Gdk, GLib

PID = os.path.expanduser("~/.cache/keymap/window.pid")

def running_pid():
    try:
        pid = int(open(PID).read())
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            if b"keys-window.py" in f.read(): return pid
    except Exception: pass
    return None

def main(url):
    old = running_pid()
    if old:                       # toggle: second Cmd+/ closes the open window
        os.kill(old, signal.SIGTERM); os.remove(PID); sys.exit(3)   # 3 = toggled closed (wrapper must not retry)
    open(PID, "w").write(str(os.getpid()))
    app = Gtk.Application(application_id="org.scottnelson.keymap")
    def activate(app):
        css = Gtk.CssProvider(); css.load_from_string("window, .background { background-color: transparent; }")
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        win = Gtk.ApplicationWindow(application=app, title="Keymap", decorated=False)
        wv = WebKit.WebView(); wv.set_background_color(Gdk.RGBA(0, 0, 0, 0))
        wv.load_uri(url); win.set_child(wv)
        keys = Gtk.EventControllerKey(); keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)  # see Esc before the webview does
        def on_key(_c, keyval, _code, _state):
            if keyval == Gdk.KEY_Escape: win.close(); return True
            return False
        keys.connect("key-pressed", on_key); win.add_controller(keys)
        win.maximize(); win.present()
    app.connect("activate", activate)
    try: app.run(None)
    finally:
        if os.path.exists(PID) and open(PID).read() == str(os.getpid()): os.remove(PID)

if __name__ == "__main__":
    main(sys.argv[1])
