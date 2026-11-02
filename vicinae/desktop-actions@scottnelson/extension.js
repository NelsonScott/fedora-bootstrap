// Desktop Actions: tiny D-Bus surface for scripts. Test from a shell:
//   gdbus call --session --dest org.gnome.Shell --object-path /org/scottnelson/DesktopActions \
//     --method org.scottnelson.DesktopActions.Tile 0 0 0.5 0.5      # top-left quarter
//   ... .MinimizeAll
//   ... .TileAll      # snap every window on the current workspace into a layout, per monitor
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Steam launches games as steam_app_<appid>; gamescope wraps them when in use.
const GAME_CLASS = /^(steam_app_|gamescope)/i;

// Named slots for rules.json, as work-area fractions [x, y, w, h].
const SLOTS = {
    'left':         [0, 0, 0.67, 1],
    'right':        [0.67, 0, 0.33, 1],
    'right-top':    [0.67, 0, 0.33, 0.5],
    'right-bottom': [0.67, 0.5, 0.33, 0.5],
    'left-top':     [0, 0, 0.67, 0.5],
    'left-bottom':  [0, 0.5, 0.67, 0.5],
    'top':          [0, 0, 1, 0.5],
    'bottom':       [0, 0.5, 1, 0.5],
};
// Smallest tile (logical px) worth putting a window in; Chrome refuses widths under ~500.
const MIN_TILE_W = 500, MIN_TILE_H = 300;
const RULES_PATH = GLib.build_filenamev([GLib.get_user_config_dir(), 'desktop-actions', 'rules.json']);

// rules.json: {"rules": [{"class": "org.mozilla.firefox", "title": "YouTube", "monitor": "right", "slot": "top"}, ...]}
// class = exact wm_class; title = case-insensitive substring (optional); monitor = primary | secondary |
// left | right | <index> (optional, window is moved there first); slot = a tile name of that monitor's
// Tiling Shell layout (left, right, top, bottom, left-top, center, right-bottom, ...) or a SLOTS key.
// Read on every call so edits apply on the next key press.
function loadRules() {
    try {
        const [ok, bytes] = GLib.file_get_contents(RULES_PATH);
        if (!ok) return [];
        const rules = JSON.parse(new TextDecoder().decode(bytes)).rules ?? [];
        return rules.filter(r => r.class && (r.slot || r.monitor !== undefined));
    } catch (e) {
        if (!e.matches?.(GLib.FileError, GLib.FileError.NOENT)) console.warn(`desktop-actions: rules.json: ${e.message}`);
        return [];
    }
}

function ruleFor(win, rules) {
    const cls = win.get_wm_class() ?? '', title = (win.get_title() ?? '').toLowerCase();
    return rules.find(r => r.class === cls && (!r.title || title.includes(r.title.toLowerCase()))) ?? null;
}

// Name a tile by where it sits: left/center/right + top/bottom, e.g. "left", "top", "right-bottom".
function tileName([x, y, w, h]) {
    const cx = x + w / 2, cy = y + h / 2;
    const horiz = w >= 0.99 ? '' : cx < 0.4 ? 'left' : cx > 0.6 ? 'right' : 'center';
    const vert = h >= 0.99 ? '' : cy < 0.5 ? 'top' : 'bottom';
    return [horiz, vert].filter(Boolean).join('-') || 'full';
}

// Tiling Shell's selected layout for this workspace+monitor as [[x, y, w, h], ...], or null.
function tilingShellTiles(wsIndex, monIndex) {
    try {
        const ext = Main.extensionManager.lookup('tilingshell@ferrarodomenico.com');
        if (!ext?.path) return null;
        const src = Gio.SettingsSchemaSource.new_from_directory(`${ext.path}/schemas`, Gio.SettingsSchemaSource.get_default(), false);
        const schema = src.lookup('org.gnome.shell.extensions.tilingshell', true);
        if (!schema) return null;
        const st = new Gio.Settings({settings_schema: schema});
        const layouts = JSON.parse(st.get_string('layouts-json'));
        const sel = st.get_value('selected-layouts').deep_unpack();
        const id = (sel[wsIndex] ?? sel[0] ?? [])[monIndex];
        const layout = layouts.find(l => l.id === id);
        if (!layout?.tiles?.length) return null;
        return layout.tiles.map(t => [t.x, t.y, t.width, t.height]);
    } catch (e) {
        console.warn(`desktop-actions: tiling shell layout: ${e.message}`);
        return null;
    }
}

// Resolve a rule's "monitor" to an index, or null.
function monitorIndex(spec) {
    const n = global.display.get_n_monitors();
    if (typeof spec === 'number') return spec >= 0 && spec < n ? spec : null;
    const primary = global.display.get_primary_monitor();
    const byX = [...Array(n).keys()].sort((a, b) => global.display.get_monitor_geometry(a).x - global.display.get_monitor_geometry(b).x);
    switch (spec) {
    case 'primary': return primary;
    case 'secondary': return byX.find(i => i !== primary) ?? null;
    case 'left': return byX[0];
    case 'right': return byX[byX.length - 1];
    default: return null;
    }
}

const IFACE = `
<node>
  <interface name="org.scottnelson.DesktopActions">
    <method name="Tile">
      <arg type="d" name="x" direction="in"/><arg type="d" name="y" direction="in"/>
      <arg type="d" name="w" direction="in"/><arg type="d" name="h" direction="in"/>
      <arg type="s" name="result" direction="out"/>
    </method>
    <method name="MinimizeAll"><arg type="i" name="count" direction="out"/></method>
    <method name="TileAll"><arg type="s" name="result" direction="out"/></method>
    <method name="ListWindows"><arg type="s" name="json" direction="out"/></method>
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

    // Layout for n windows, as fractions of the monitor work area (x, y, w, h).
    _layout(n) {
        if (n <= 1) return [[0, 0, 1, 1]];
        if (n === 2) return [[0, 0, 0.67, 1], [0.67, 0, 0.33, 1]];
        if (n === 3) return [[0, 0, 0.67, 1], [0.67, 0, 0.33, 0.5], [0.67, 0.5, 0.33, 0.5]];
        const cols = Math.ceil(Math.sqrt(n)), rows = Math.ceil(n / cols);
        const out = [];
        for (let i = 0; i < n; i++) {
            const c = i % cols, r = Math.floor(i / cols);
            const lastRow = r === rows - 1, inLast = n - (rows - 1) * cols;
            const w = lastRow ? 1 / inLast : 1 / cols;
            out.push([lastRow ? c * w : c / cols, r / rows, w, 1 / rows]);
        }
        return out;
    }

    // Largest region not covered by the taken slots: the left column if anything on the right is
    // taken, the right column if the left is taken, or the whole area.
    _freeArea(takenSlots) {
        const top = takenSlots.includes('top'), bottom = takenSlots.includes('bottom');
        if (top && bottom) return [0, 0, 1, 1];
        if (top) return SLOTS['bottom'];
        if (bottom) return SLOTS['top'];
        const left = takenSlots.some(t => t.startsWith('left')), right = takenSlots.some(t => t.startsWith('right'));
        if (left && right) return [0, 0, 1, 1];
        if (right) return SLOTS['left'];
        if (left) return SLOTS['right'];
        return [0, 0, 1, 1];
    }

    // Share one tile among n overflow windows: stack them in a tall tile, put them side by side in a
    // wide one (equal parts), grid when there are many. Returns work-area fractions.
    _subdivide(n, [tx, ty, tw, th], wa) {
        const portrait = th * wa.height > tw * wa.width;
        let parts;
        if (n <= 3) parts = portrait ? [...Array(n)].map((_, i) => [0, i / n, 1, 1 / n]) : [...Array(n)].map((_, i) => [i / n, 0, 1 / n, 1]);
        else parts = this._layout(n);
        return parts.map(([x, y, w, h]) => [tx + x * tw, ty + y * th, w * tw, h * th]);
    }

    _place(win, wa, [x, y, w, h]) {
        if (win.is_fullscreen()) win.unmake_fullscreen();
        if (win.maximized_horizontally || win.maximized_vertically) {
            try { win.unmaximize(); } catch (_) { win.unmaximize(Meta.MaximizeFlags.BOTH); }
        }
        win.move_resize_frame(true, wa.x + Math.round(wa.width * x), wa.y + Math.round(wa.height * y),
            Math.round(wa.width * w), Math.round(wa.height * h));
    }

    // Snap every normal, visible window on the active workspace into tiles, one layout per monitor.
    // Tiles come from Tiling Shell's selected layout for that monitor (fallback: a count-based layout).
    // rules.json can move a window to a monitor and pin it to a named tile; the rest fill the remaining
    // tiles most-recently-used first, and any overflow shares the largest tile.
    TileAll() {
        const ws = global.workspace_manager.get_active_workspace();
        const rules = loadRules();
        const wins = global.get_window_actors().map(a => a.meta_window).filter(w =>
            w.window_type === Meta.WindowType.NORMAL && !w.minimized &&
            // Fullscreen games stay fullscreen; other fullscreen windows (a Firefox video) get tiled.
            !(w.is_fullscreen() && GAME_CLASS.test(w.get_wm_class() ?? '')) &&
            (w.get_workspace() === ws || w.is_on_all_workspaces()) &&
            w.allows_resize() && w.allows_move());
        // Most recently used first, so each rule claims the window you touched last.
        wins.sort((a, b) => b.get_user_time() - a.get_user_time());
        const byMon = new Map(), used = new Set();
        for (const w of wins) {
            const rule = ruleFor(w, rules.filter(r => !used.has(r)));
            if (rule) used.add(rule);
            let m = w.get_monitor();
            const target = rule?.monitor !== undefined ? monitorIndex(rule.monitor) : null;
            if (target !== null && target !== m) { w.move_to_monitor(target); m = target; }
            if (!byMon.has(m)) byMon.set(m, []);
            byMon.get(m).push({w, slot: rule?.slot ?? null});
        }
        const done = [];
        for (const [m, items] of byMon) {
            const wa = ws.get_work_area_for_monitor(m);
            let fromTS = tilingShellTiles(ws.index(), m);
            // A rule asking for a tile this Tiling Shell layout doesn't have (e.g. "top" on "5 Tiles"
            // after Tiling Shell regenerated its layouts) falls back to the built-in slots, so the rule
            // still wins over whatever layout the monitor drifted to. (Scott, 2026-10-09)
            if (fromTS && items.some(it => it.slot && !fromTS.map(tileName).includes(it.slot))) fromTS = null;
            // A layout with tiles too small for a real window (e.g. "5 Tiles" on the 1080-wide portrait
            // monitor: 238 px side strips, narrower than Chrome's ~500 px minimum) is useless; use the
            // built-in slots instead. Tiling Shell re-selects its first layout for a monitor every time
            // the monitor count changes, so this drift recurs whenever the 32" drops out. (2026-10-14)
            if (fromTS && fromTS.some(([, , w, h]) => w * wa.width < MIN_TILE_W || h * wa.height < MIN_TILE_H)) fromTS = null;
            // Named tiles: Tiling Shell's layout if available, else the built-in SLOTS table.
            const named = fromTS ? fromTS.map(t => [tileName(t), t]) : Object.entries(SLOTS);
            const free = fromTS ? [...named] : null;   // tiles still unassigned (Tiling Shell mode)
            const rest = [];
            for (const it of items) {
                const hit = it.slot && named.find(([n]) => n === it.slot);
                const idx = hit ? (free ? free.indexOf(hit) : 0) : -1;
                if (hit && (!free || idx >= 0)) {
                    if (free) free.splice(idx, 1);
                    this._place(it.w, wa, hit[1]); done.push(`${m}:${it.w.get_wm_class()}@${hit[0]}`);
                } else rest.push(it.w);
            }
            if (!rest.length) continue;
            if (free) {
                // Fill remaining tiles in layout order; overflow windows subdivide the largest remaining tile.
                const pool = free.length ? free : [named.reduce((a, b) => (a[1][2] * a[1][3] >= b[1][2] * b[1][3] ? a : b))];
                const direct = rest.slice(0, Math.max(0, pool.length - 1)), overflow = rest.slice(direct.length);
                direct.forEach((w, i) => { this._place(w, wa, pool[i][1]); done.push(`${m}:${w.get_wm_class()}@${pool[i][0]}`); });
                const last = pool[direct.length][1];
                const tiles = this._subdivide(overflow.length, last, wa);
                overflow.forEach((w, i) => { this._place(w, wa, tiles[i]); done.push(`${m}:${w.get_wm_class()}`); });
            } else {
                const takenNames = done.filter(d => d.startsWith(`${m}:`) && d.includes('@')).map(d => d.split('@')[1]);
                const area = this._freeArea(takenNames);
                // Portrait area: stack windows full-width (_subdivide); landscape: the 2/3 + 1/3 layouts.
                const portrait = area[3] * wa.height > area[2] * wa.width;
                const tiles = portrait ? this._subdivide(rest.length, area, wa)
                    : this._layout(rest.length).map(([x, y, w, h]) => [area[0] + x * area[2], area[1] + y * area[3], w * area[2], h * area[3]]);
                rest.forEach((w, i) => { this._place(w, wa, tiles[i]); done.push(`${m}:${w.get_wm_class()}`); });
            }
        }
        return done.length ? done.join(', ') : 'no windows';
    }

    // Read-only: normal windows with monitor, workspace, frame geometry and state (for scripts/QA).
    ListWindows() {
        const focus = global.display.focus_window;
        const out = [];
        for (const a of global.get_window_actors()) {
            const w = a.meta_window;
            if (w.window_type !== Meta.WindowType.NORMAL) continue;
            const r = w.get_frame_rect();
            out.push({cls: w.get_wm_class(), title: w.get_title(), mon: w.get_monitor(), ws: w.get_workspace()?.index() ?? -1,
                x: r.x, y: r.y, w: r.width, h: r.height, max: w.maximized_horizontally && w.maximized_vertically,
                full: w.is_fullscreen(), min: w.minimized, focus: w === focus});
        }
        return JSON.stringify(out);
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
