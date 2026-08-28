#!/usr/bin/env python3
"""Take a screenshot via xdg-desktop-portal (works on GNOME Wayland headless)."""
import sys, dbus, time
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
portal = bus.get_object('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop')
sc = dbus.Interface(portal, 'org.freedesktop.portal.Screenshot')
loop = GLib.MainLoop(); out = {}
def on_resp(code, results):
    out['uri'] = str(results.get('uri', '')); out['code'] = int(code); loop.quit()
bus.add_signal_receiver(on_resp, 'Response', 'org.freedesktop.portal.Request')
sc.Screenshot('', {'interactive': dbus.Boolean(False), 'handle_token': 'qa%d' % int(time.time())})
GLib.timeout_add(8000, loop.quit); loop.run()
print(out.get('uri', 'FAILED %s' % out))
