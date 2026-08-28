import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const POLL_SECONDS = 120;
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage';
const CREDS_PATH = GLib.build_filenamev([GLib.get_home_dir(), '.claude', '.credentials.json']);

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

function fmtReset(iso) {
    if (!iso) return '';
    const t = GLib.DateTime.new_from_iso8601(iso, null);
    if (!t) return '';
    const now = GLib.DateTime.new_now_local();
    const diffMin = Math.max(0, Math.round(t.difference(now) / 60e6));
    const local = t.to_local();
    if (diffMin < 24 * 60) {
        const h = Math.floor(diffMin / 60), m = diffMin % 60;
        return `resets in ${h ? h + 'h ' : ''}${m}m (${local.format('%-I:%M %p')})`;
    }
    return `resets ${local.format('%a %-I:%M %p')}`;
}

class BarRow extends PopupMenu.PopupBaseMenuItem {
    static {
        GObject.registerClass(this);
    }

    _init(title) {
        super._init({reactive: false, style_class: 'claude-usage-row'});
        const box = new St.BoxLayout({vertical: true, x_expand: true});
        const top = new St.BoxLayout({x_expand: true});
        this._title = new St.Label({text: title, style_class: 'claude-usage-title', x_expand: true});
        this._pct = new St.Label({text: '–', style_class: 'claude-usage-title'});
        top.add_child(this._title);
        top.add_child(this._pct);
        this._sub = new St.Label({text: '', style_class: 'claude-usage-sub'});
        this._bg = new St.Widget({style_class: 'claude-usage-bar-bg'});
        this._fill = new St.Widget({style_class: 'claude-usage-bar-ok'});
        this._bg.add_child(this._fill);
        box.add_child(top);
        box.add_child(this._sub);
        box.add_child(this._bg);
        this.add_child(box);
    }

    update(pct, resetIso, subPrefix = '') {
        this._pct.text = `${Math.round(pct)}%`;
        const reset = fmtReset(resetIso);
        this._sub.text = subPrefix ? `${subPrefix} · ${reset}` : reset;
        this._fill.style_class = `claude-usage-bar-${sevClass(pct)}`;
        this._fill.width = Math.round(260 * Math.min(100, Math.max(0, pct)) / 100);
    }
}

class Indicator extends PanelMenu.Button {
    static {
        GObject.registerClass(this);
    }

    _init(extPath) {
        super._init(0.5, 'Claude Usage');
        const box = new St.BoxLayout({style_class: 'claude-usage-box'});
        this._icon = new St.Icon({
            gicon: new Gio.FileIcon({
                file: Gio.File.new_for_path(GLib.build_filenamev([extPath, 'claude-symbolic.svg'])),
            }),
            style_class: 'system-status-icon claude-usage-icon',
        });
        this._label = new St.Label({
            text: '…',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'claude-usage-label',
        });
        box.add_child(this._icon);
        box.add_child(this._label);
        this.add_child(box);

        this._rows = {};
        this._rowsBox = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._rowsBox);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._status = new PopupMenu.PopupMenuItem('', {reactive: false});
        this._status.label.style_class = 'claude-usage-sub';
        this.menu.addMenuItem(this._status);
        this.menu.addAction('Refresh', () => this._refresh());
        const link = this.menu.addAction('claude.ai →', () => {
            Gio.AppInfo.launch_default_for_uri('https://claude.ai/settings/usage', null);
        });
        link?.label?.set_style_class_name('claude-usage-link');

        this._session = new Soup.Session({timeout: 20});
        this._lastOk = null;
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

    _refresh() {
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
                    this._setError('429', 'Rate-limited by API – will retry next poll');
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

    _apply(data) {
        // Prefer the structured limits[] array; fall back to legacy fields.
        const items = [];
        if (Array.isArray(data.limits) && data.limits.length) {
            for (const l of data.limits) {
                let key, title, short;
                if (l.kind === 'session') { key = 'session'; title = 'Session'; short = ''; }
                else if (l.kind === 'weekly_all') { key = 'weekly'; title = 'Weekly · all models'; short = 'W'; }
                else if (l.kind === 'weekly_scoped') {
                    const name = l.scope?.model?.display_name ?? l.scope?.surface ?? 'scoped';
                    key = `scoped:${name}`; title = `Weekly · ${name}`; short = name[0];
                } else { key = l.kind; title = l.kind; short = l.kind[0]; }
                items.push({key, title, short, pct: l.percent ?? 0, reset: l.resets_at,
                            sub: l.kind === 'session' ? '5-hour' : ''});
            }
        } else {
            if (data.five_hour) items.push({key: 'session', title: 'Session (5-hour)', short: '', pct: data.five_hour.utilization, reset: data.five_hour.resets_at});
            if (data.seven_day) items.push({key: 'weekly', title: 'Weekly (all models)', short: 'W', pct: data.seven_day.utilization, reset: data.seven_day.resets_at});
            for (const [k, n] of [['seven_day_opus', 'Opus'], ['seven_day_sonnet', 'Sonnet']])
                if (data[k]) items.push({key: `scoped:${n}`, title: `Weekly · ${n}`, short: n[0], pct: data[k].utilization, reset: data[k].resets_at});
        }

        let maxPct = 0;
        const parts = [];
        for (const it of items) {
            this._getRow(it.key, it.title).update(it.pct, it.reset, it.sub ?? '');
            parts.push(`${it.short}${Math.round(it.pct)}%`);
            maxPct = Math.max(maxPct, it.pct);
        }
        this._label.text = parts.join(' · ') || '–';
        console.log(`[claude-usage] ${this._label.text}`);
        const sev = sevClass(maxPct);
        this._label.style_class = 'claude-usage-label' + (sev === 'ok' ? '' : ` claude-usage-${sev}`);
        this._lastOk = GLib.DateTime.new_now_local();
        this._status.label.text = `Updated ${this._lastOk.format('%-I:%M %p')} · polls every ${POLL_SECONDS / 60} min`;
    }

    _setError(short, long) {
        console.warn(`[claude-usage] ${long}`);
        this._label.style_class = 'claude-usage-label claude-usage-stale';
        if (!this._lastOk) this._label.text = short;
        this._status.label.text = long + (this._lastOk ? ` (last ok ${this._lastOk.format('%-I:%M %p')})` : '');
    }

    destroy() {
        if (this._timer) { GLib.source_remove(this._timer); this._timer = null; }
        this._session?.abort();
        super.destroy();
    }
}

const DBUS_IFACE = `<node><interface name="org.scottnelson.ClaudeUsage">
  <method name="OpenMenu"/><method name="Refresh"/></interface></node>`;

export default class ClaudeUsageExtension extends Extension {
    OpenMenu() { this._indicator?._refresh(); this._indicator?.menu.open(true); }
    Refresh() { this._indicator?._refresh(); }
    enable() {
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
