import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Layout follows option "2d" (dropdown) + "2b" (bar) from the Claude Design
// project "Open Router widget design" / Menu Bar Widget.dc.html:
//   bar      ✳ 76%  W 81%     (session + whichever weekly is tightest; W tints red ≥ 80%)
//   dropdown CLAUDE rows with 4px bars · OPENROUTER "Credits left $4.77 of $66" · one-line footer

const POLL_SECONDS = 120;
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage';
const CREDS_PATH = GLib.build_filenamev([GLib.get_home_dir(), '.claude', '.credentials.json']);
const OR_CACHE_PATH = GLib.build_filenamev([GLib.get_home_dir(), '.cache', 'openrouter-usage.json']);
const OR_STALE_SECONDS = 2 * 3600; // written every 30 min by openrouter-usage.timer
const WEEK_HOT_PCT = 80;           // 2b: weekly figure in the bar goes warm red from here

function readToken() {
    try {
        const [ok, bytes] = GLib.file_get_contents(CREDS_PATH);
        if (!ok) return null;
        const j = JSON.parse(new TextDecoder().decode(bytes));
        return j?.claudeAiOauth?.accessToken ?? null;
    } catch (e) {
        return null;
    }
}

function sevClass(pct) {
    if (pct >= 90) return 'crit';
    if (pct >= 70) return 'warn';
    return 'ok';
}

function clampPct(pct) {
    return Math.min(100, Math.max(0, Number.isFinite(pct) ? pct : 0));
}

// "resets in 42m" / "resets 2:10 PM" / "resets Thu 3:00 PM"
function fmtReset(iso) {
    if (!iso) return '';
    const t = GLib.DateTime.new_from_iso8601(iso, null);
    if (!t) return '';
    const now = GLib.DateTime.new_now_local();
    const diffMin = Math.max(0, Math.round(t.difference(now) / 60e6));
    const local = t.to_local();
    if (diffMin < 60) return `resets in ${diffMin}m`;
    if (diffMin < 24 * 60) return `resets ${local.format('%-I:%M %p')}`;
    return `resets ${local.format('%a %-I:%M %p')}`;
}

class HeaderItem extends PopupMenu.PopupBaseMenuItem {
    static {
        GObject.registerClass(this);
    }

    _init(text) {
        super._init({reactive: false, can_focus: false, style_class: 'claude-usage-hdr'});
        // St has no text-transform; uppercase here.
        this.add_child(new St.Label({text: text.toUpperCase(), style_class: 'claude-usage-hdr-text', x_expand: true}));
    }
}

// Track + fill for a 4px bar. The fill is sized inside vfunc_allocate from the REAL
// allocation box, never from this.width: while the menu is closed an unallocated
// St.Widget reports its *natural* width (= the fill child's own width), so the old
// "fill.width = bg.width * frac" on every 2-min poll multiplied the fill by frac
// again and again until every bar decayed to 0px (Sep 15 2026 bug).
class BarTrack extends St.Widget {
    static {
        GObject.registerClass(this);
    }

    _init(params) {
        super._init(params);
        this._frac = 0;
        this.fill = new St.Widget({style_class: 'claude-usage-bar-ok'});
        this.add_child(this.fill);
    }

    setFrac(frac) {
        this._frac = frac;
        this.queue_relayout();
    }

    vfunc_allocate(box) {
        this.set_allocation(box);
        const content = this.get_theme_node().get_content_box(box);
        const w = Math.round(content.get_width() * this._frac);
        this.fill.allocate(new Clutter.ActorBox({x1: content.x1, y1: content.y1, x2: content.x1 + w, y2: content.y2}));
    }
}

// One "2d" row:   Name ............ 76%
//                 ▬▬▬▬▬▬▬▬▬▬▬▬▬▬  resets 2:10 PM
class BarRow extends PopupMenu.PopupBaseMenuItem {
    static {
        GObject.registerClass(this);
    }

    _init(title) {
        super._init({reactive: false, can_focus: false, style_class: 'claude-usage-row'});
        const box = new St.BoxLayout({vertical: true, x_expand: true, style_class: 'claude-usage-rowbox'});

        const top = new St.BoxLayout({x_expand: true});
        this._name = new St.Label({text: title, style_class: 'claude-usage-name', x_expand: true, y_align: Clutter.ActorAlign.END});
        this._value = new St.Label({text: '–', style_class: 'claude-usage-value', y_align: Clutter.ActorAlign.END});
        this._suffix = new St.Label({text: '', style_class: 'claude-usage-value-suffix', y_align: Clutter.ActorAlign.END, visible: false});
        top.add_child(this._name);
        top.add_child(this._value);
        top.add_child(this._suffix);

        const line = new St.BoxLayout({x_expand: true, style_class: 'claude-usage-barline'});
        this._bg = new BarTrack({style_class: 'claude-usage-bar-bg', x_expand: true, y_align: Clutter.ActorAlign.CENTER, clip_to_allocation: true});
        this._fill = this._bg.fill;
        this._sub = new St.Label({text: '', style_class: 'claude-usage-sub', y_align: Clutter.ActorAlign.CENTER});
        line.add_child(this._bg);
        line.add_child(this._sub);

        box.add_child(top);
        box.add_child(line);
        this.add_child(box);
    }

    // Claude limit row: bar = % used, colour by severity.
    update(pct, resetIso) {
        this.setValues(pct, `${Math.round(pct)}%`, fmtReset(resetIso), {barClass: sevClass(pct)});
    }

    setValues(pct, valueText, subText, {barClass = 'ok', suffix = '', valueClass = ''} = {}) {
        this._value.text = valueText;
        this._value.style_class = 'claude-usage-value' + (valueClass ? ` ${valueClass}` : '');
        this._suffix.text = suffix;
        this._suffix.visible = !!suffix;
        this._sub.text = subText;
        this._fill.style_class = `claude-usage-bar-${barClass}`;
        this._bg.setFrac(clampPct(pct) / 100);
    }
}

class Indicator extends PanelMenu.Button {
    static {
        GObject.registerClass(this);
    }

    _init(extPath) {
        super._init(0.5, 'Claude Usage');

        // ---- panel: ✳ 76%  W 81% ----
        const box = new St.BoxLayout({style_class: 'claude-usage-box'});
        this._icon = new St.Icon({
            gicon: new Gio.FileIcon({
                file: Gio.File.new_for_path(GLib.build_filenamev([extPath, 'claude-symbolic.svg'])),
            }),
            style_class: 'system-status-icon claude-usage-icon',
        });
        this._label = new St.Label({text: '…', y_align: Clutter.ActorAlign.CENTER, style_class: 'claude-usage-label'});
        this._week = new St.Label({text: '', y_align: Clutter.ActorAlign.CENTER, style_class: 'claude-usage-week', visible: false});
        box.add_child(this._icon);
        box.add_child(this._label);
        box.add_child(this._week);
        this.add_child(box);

        // ---- dropdown (2d) ----
        this.menu.actor.add_style_class_name('claude-usage-menu');

        this.menu.addMenuItem(new HeaderItem('Claude'));
        this._rows = {};
        this._rowsBox = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._rowsBox);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.menu.addMenuItem(new HeaderItem('OpenRouter'));
        this._orRow = new BarRow('Credits left');
        this.menu.addMenuItem(this._orRow);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // footer: status text on the left, "Refresh" on the right; the whole row is clickable
        this._footer = new PopupMenu.PopupBaseMenuItem({style_class: 'claude-usage-footer'});
        this._status = new St.Label({text: '', style_class: 'claude-usage-footer-text', x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        this._footer.add_child(this._status);
        this._footer.add_child(new St.Label({text: 'Refresh', style_class: 'claude-usage-refresh', y_align: Clutter.ActorAlign.CENTER}));
        this._footer.connect('activate', () => this._refresh(true));
        this.menu.addMenuItem(this._footer);

        const link = new PopupMenu.PopupBaseMenuItem({style_class: 'claude-usage-linkrow'});
        link.add_child(new St.Label({text: 'claude.ai →', style_class: 'claude-usage-link', x_expand: true}));
        link.connect('activate', () => Gio.AppInfo.launch_default_for_uri('https://claude.ai/settings/usage', null));
        this.menu.addMenuItem(link);

        this._session = new Soup.Session({timeout: 20});
        this._lastOk = null;
        this._backoffUntil = 0; // unix secs; set from a 429's Retry-After
        this._refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, POLL_SECONDS, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _getRow(key, title) {
        if (!this._rows[key]) {
            this._rows[key] = new BarRow(title);
            this._rowsBox.addMenuItem(this._rows[key]);
        }
        return this._rows[key];
    }

    // force=true (Refresh click / D-Bus) ignores a pending Retry-After backoff.
    _refresh(force = false) {
        this._refreshOpenRouter();
        const nowSecs = GLib.DateTime.new_now_local().to_unix();
        if (!force && nowSecs < this._backoffUntil) {
            const at = GLib.DateTime.new_from_unix_local(this._backoffUntil).format('%-I:%M %p');
            this._status.text = `Rate-limited · retrying ${at}` + (this._lastOk ? ` · last ok ${this._lastOk.format('%-I:%M %p')}` : '');
            return;
        }
        // QA/demo: CLAUDE_USAGE_FIXTURE=/path/to/usage.json replaces the network call
        const fixture = GLib.getenv('CLAUDE_USAGE_FIXTURE');
        if (fixture) {
            try {
                const [, bytes] = GLib.file_get_contents(fixture);
                this._apply(JSON.parse(new TextDecoder().decode(bytes)));
            } catch (e) {
                this._setError('fixture', `Fixture error: ${e.message}`);
            }
            return;
        }
        const token = readToken();
        if (!token) {
            this._setError('no token', 'No Claude Code credentials found');
            return;
        }
        const msg = Soup.Message.new('GET', USAGE_URL);
        msg.request_headers.append('Authorization', `Bearer ${token}`);
        msg.request_headers.append('anthropic-beta', 'oauth-2025-04-20');
        msg.request_headers.append('Accept', 'application/json');
        this._session.send_and_read_async(msg, GLib.PRIORITY_DEFAULT, null, (sess, res) => {
            try {
                const bytes = sess.send_and_read_finish(res);
                let status;
                try {
                    status = msg.get_status();
                } catch (e) {
                    // libsoup's Status enum lacks some codes (e.g. 429) and GJS throws
                    const m = String(e.message ?? '').match(/\d{3}/);
                    status = m ? Number(m[0]) : 0;
                }
                if (status === 429) {
                    // Honour Retry-After (seconds); polling through it just extends the penalty.
                    const ra = parseInt(msg.response_headers.get_one('retry-after') ?? '', 10);
                    const wait = Number.isFinite(ra) && ra > 0 ? ra + 15 : 10 * 60;
                    this._backoffUntil = GLib.DateTime.new_now_local().to_unix() + wait;
                    const at = GLib.DateTime.new_from_unix_local(this._backoffUntil).format('%-I:%M %p');
                    this._setError('429', `Rate-limited by API · retrying ${at}`);
                    return;
                }
                if (status !== 200) {
                    this._setError(`HTTP ${status}`, `API error ${status} – run \`claude\` to refresh the token`);
                    return;
                }
                const data = JSON.parse(new TextDecoder().decode(bytes.get_data()));
                this._apply(data);
            } catch (e) {
                this._setError('err', `Error: ${e.message}`);
            }
        });
    }

    // OpenRouter credits come from a local cache file written by
    // openrouter-usage.timer (systemd --user) – no network and no keys in GJS.
    // Shown as what's LEFT ("$4.77 of $66"), bar = remaining share (2d).
    _refreshOpenRouter() {
        try {
            const [ok, bytes] = GLib.file_get_contents(OR_CACHE_PATH);
            if (!ok) throw new Error('no cache file');
            const j = JSON.parse(new TextDecoder().decode(bytes));
            const used = j.total_usage, total = j.total_credits;
            const age = GLib.DateTime.new_now_local().to_unix() - (j.fetched_at ?? 0);
            if (age > OR_STALE_SECONDS || !Number.isFinite(used) || !Number.isFinite(total))
                throw new Error('stale');
            const left = Math.max(0, total - used);
            const pct = total > 0 ? 100 * left / total : 0;
            const fetched = GLib.DateTime.new_from_unix_local(j.fetched_at).format('%H:%M');
            this._orRow.setValues(pct, `$${left.toFixed(2)}`, `fetched ${fetched}`,
                {barClass: 'amber', suffix: `of $${Math.round(total)}`, valueClass: 'claude-usage-value-amber'});
        } catch (e) {
            this._orRow.setValues(0, '–', 'no data', {barClass: 'amber'});
        }
    }

    _apply(data) {
        // Prefer the structured limits[] array; fall back to legacy fields.
        const items = [];
        if (Array.isArray(data.limits) && data.limits.length) {
            for (const l of data.limits) {
                let key, title, weekly = false;
                if (l.kind === 'session') { key = 'session'; title = 'Session'; }
                else if (l.kind === 'weekly_all') { key = 'weekly'; title = 'Weekly · all models'; weekly = true; }
                else if (l.kind === 'weekly_scoped') {
                    const name = l.scope?.model?.display_name ?? l.scope?.surface ?? 'scoped';
                    key = `scoped:${name}`; title = `Weekly · ${name}`; weekly = true;
                } else { key = l.kind; title = l.kind; }
                items.push({key, title, weekly, pct: l.percent ?? 0, reset: l.resets_at});
            }
        } else {
            if (data.five_hour) items.push({key: 'session', title: 'Session', weekly: false, pct: data.five_hour.utilization, reset: data.five_hour.resets_at});
            if (data.seven_day) items.push({key: 'weekly', title: 'Weekly · all models', weekly: true, pct: data.seven_day.utilization, reset: data.seven_day.resets_at});
            for (const [k, n] of [['seven_day_opus', 'Opus'], ['seven_day_sonnet', 'Sonnet']])
                if (data[k]) items.push({key: `scoped:${n}`, title: `Weekly · ${n}`, weekly: true, pct: data[k].utilization, reset: data[k].resets_at});
        }

        let session = null, tightestWeek = null;
        for (const it of items) {
            this._getRow(it.key, it.title).update(it.pct, it.reset);
            if (it.key === 'session') session = it.pct;
            else if (it.weekly && (tightestWeek === null || it.pct > tightestWeek)) tightestWeek = it.pct;
        }

        // bar (2a/2b): session % + tightest weekly; nothing about OpenRouter up here
        const sessPct = session ?? (items[0]?.pct ?? 0);
        this._label.text = `${Math.round(sessPct)}%`;
        const sev = sevClass(sessPct);
        this._label.style_class = 'claude-usage-label' + (sev === 'ok' ? '' : ` claude-usage-${sev}`);
        if (tightestWeek !== null) {
            this._week.text = `W ${Math.round(tightestWeek)}%`;
            this._week.style_class = 'claude-usage-week' + (tightestWeek >= WEEK_HOT_PCT ? ' claude-usage-crit' : '');
            this._week.visible = true;
        } else {
            this._week.visible = false;
        }
        console.log(`[claude-usage] ${this._label.text} ${this._week.visible ? this._week.text : ''}`.trim());

        this._lastOk = GLib.DateTime.new_now_local();
        this._status.text = `Updated ${this._lastOk.format('%-I:%M %p')} · every ${POLL_SECONDS / 60} min`;
    }

    _setError(short, long) {
        console.warn(`[claude-usage] ${long}`);
        this._label.style_class = 'claude-usage-label claude-usage-stale';
        this._week.style_class = 'claude-usage-week claude-usage-stale';
        if (!this._lastOk) this._label.text = short;
        this._status.text = long + (this._lastOk ? ` (last ok ${this._lastOk.format('%-I:%M %p')})` : '');
    }

    destroy() {
        if (this._timer) { GLib.source_remove(this._timer); this._timer = null; }
        this._session?.abort();
        super.destroy();
    }
}

const DBUS_IFACE = `<node><interface name="org.scottnelson.ClaudeUsage">
  <method name="OpenMenu"/><method name="OpenMenuRaw"/><method name="CloseMenu"/><method name="Refresh"/>
  <method name="Snap"><arg type="s" name="path" direction="in"/></method>
</interface></node>`;

export default class ClaudeUsageExtension extends Extension {
    OpenMenu() { this._indicator?._refresh(); this._indicator?.menu.open(true); }
    // QA: open/close WITHOUT a refresh, to reproduce live timing (data applied while the menu is closed).
    OpenMenuRaw() { this._indicator?.menu.open(true); }
    CloseMenu() { this._indicator?.menu.close(true); }
    Refresh() { this._indicator?._refresh(true); }

    // QA helper: screenshot the shell (works inside `gnome-shell --devkit` too).
    Snap(path) {
        try {
            const stream = Gio.File.new_for_path(path).replace(null, false, Gio.FileCreateFlags.NONE, null);
            const shooter = new Shell.Screenshot();
            shooter.screenshot(false, stream, (o, res) => {
                try { shooter.screenshot_finish(res); console.log(`[claude-usage] snap -> ${path}`); }
                catch (e) { console.warn(`[claude-usage] snap failed: ${e.message}`); }
                finally { stream.close(null); }
            });
        } catch (e) {
            console.warn(`[claude-usage] snap failed: ${e.message}`);
        }
    }

    enable() {
        console.log('[claude-usage] enable (2d build)');
        this._dbus = Gio.DBusExportedObject.wrapJSObject(DBUS_IFACE, this);
        this._dbus.export(Gio.DBus.session, '/org/scottnelson/ClaudeUsage');
        this._indicator = new Indicator(this.path);
        // position 0 in the right box = leftmost of the right-hand indicators
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');
    }

    disable() {
        this._dbus?.unexport(); this._dbus = null;
        this._indicator?.destroy();
        this._indicator = null;
    }
}
