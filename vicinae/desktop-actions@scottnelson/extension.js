// Desktop Actions: tiny D-Bus surface for scripts. Test from a shell:
//   gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/DesktopActions \
//     --method org.scottnelson.DesktopActions.Tile 0 0 0.5 0.5      # top-left quarter
//   ... .MinimizeAll
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const IFACE = `
<node>
  <interface name="org.scottnelson.DesktopActions">
    <method name="Tile">
      <arg type="d" name="x" direction="in"/><arg type="d" name="y" direction="in"/>
      <arg type="d" name="w" direction="in"/><arg type="d" name="h" direction="in"/>
      <arg type="s" name="result" direction="out"/>
    </method>
    <method name="MinimizeAll"><arg type="i" name="count" direction="out"/></method>
    <method name="FocusedWindow"><arg type="s" name="title" direction="out"/></method>
  </interface>
</node>`;

export default class DesktopActions extends Extension {
    enable() {
        this._dbus = Gio.DBusExportedObject.wrapJSObject(IFACE, this);
        this._dbus.export(Gio.DBus.session, '/org/scottnelson/DesktopActions');
    }
    disable() {
        this._dbus?.unexport();
        this._dbus = null;
    }

    _focused() {
        const w = global.display.focus_window;
        return w && w.window_type === Meta.WindowType.NORMAL ? w : null;
    }

    Tile(x, y, w, h) {
        const win = this._focused();
        if (!win) return 'no focused window';
        // GNOME 48+ mutter: unmaximize() takes no flags; older takes MaximizeFlags.BOTH.
        if (win.maximized_horizontally || win.maximized_vertically) {
            try { win.unmaximize(); } catch (_) { win.unmaximize(Meta.MaximizeFlags.BOTH); }
        }
        if (win.is_fullscreen()) win.unmake_fullscreen();
        const wa = win.get_work_area_current_monitor();
        const X = wa.x + Math.round(wa.width * x), Y = wa.y + Math.round(wa.height * y);
        const W = Math.round(wa.width * w), H = Math.round(wa.height * h);
        win.move_resize_frame(true, X, Y, W, H);
        return `${win.get_title()} -> ${X},${Y} ${W}x${H}`;
    }

    MinimizeAll() {
        const ws = global.workspace_manager.get_active_workspace();
        let n = 0;
        for (const a of global.get_window_actors()) {
            const w = a.meta_window;
            if (w.get_workspace() === ws && !w.minimized && w.window_type === Meta.WindowType.NORMAL) { w.minimize(); n++; }
        }
        return n;
    }

    FocusedWindow() {
        const w = this._focused();
        return w ? `${w.get_wm_class()} :: ${w.get_title()}` : '';
    }
}
