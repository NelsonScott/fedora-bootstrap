#!/usr/bin/env python3
"""Generate Vicinae script commands for every GNOME Settings panel + common system actions.
GNOME ships gnome-*-panel.desktop with NoDisplay=true, so launchers never show them; typing
'bluetooth' or 'wifi' in Vicinae found nothing. Re-run after editing PANELS/ACTIONS."""
import json, os, stat
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "scripts")
PANELS = [  # (panel, title, icon, keywords)
 ("bluetooth", "Bluetooth", "🎧", ["bluetooth","bt","pair","pairing","headphones","airpods","earbuds","controller","devices"]),
 ("wifi", "Wi-Fi", "📶", ["wifi","wi-fi","wireless","wlan","hotspot","networks","ssid"]),
 ("network", "Network", "🌐", ["network","ethernet","lan","vpn","proxy","ip address","dns","internet"]),
 ("sound", "Sound", "🔊", ["sound","audio","volume","speakers","speaker","mic","microphone","input","output","headset","alert sound"]),
 ("display", "Displays", "🖥️", ["display","displays","monitor","monitors","resolution","scaling","scale","refresh rate","hdmi","night light","orientation"]),
 ("keyboard", "Keyboard", "⌨️", ["keyboard","shortcuts","keyboard shortcuts","input sources","layout","compose key","emoji"]),
 ("mouse", "Mouse & Touchpad", "🖱️", ["mouse","touchpad","trackpad","pointer","scroll","natural scrolling","tap to click"]),
 ("power", "Power", "🔋", ["power","battery","sleep","suspend settings","screen blank","performance mode","power mode","idle"]),
 ("background", "Appearance", "🎨", ["appearance","background","wallpaper","theme","dark mode","light mode","style","accent color"]),
 ("notifications", "Notifications", "🔔", ["notifications","do not disturb","dnd","alerts","banners","lock screen notifications"]),
 ("privacy", "Privacy & Security", "🔒", ["privacy","security","location","camera access","screen lock","file history","diagnostics","thunderbolt"]),
 ("users", "Users", "👤", ["users","user","account","password","fingerprint","auto login","avatar"]),
 ("datetime", "Date & Time", "🕒", ["date","time","clock","timezone","time zone","ntp","24 hour"]),
 ("printers", "Printers", "🖨️", ["printer","printers","print","cups","scanner"]),
 ("applications", "Apps", "📦", ["apps","applications","default apps","default browser","file associations","removable media","startup"]),
 ("universal-access", "Accessibility", "♿", ["accessibility","universal access","a11y","large text","zoom","high contrast","screen reader","cursor size"]),
 ("sharing", "Sharing", "📡", ["sharing","remote desktop","rdp","media sharing","file sharing","ssh","remote login"]),
 ("region", "Region & Language", "🌍", ["region","language","locale","formats","input language"]),
 ("search", "Search", "🔍", ["search settings","search providers","overview search"]),
 ("multitasking", "Multitasking", "🗂️", ["multitasking","workspaces","hot corner","app switching","workspace"]),
 ("online-accounts", "Online Accounts", "☁️", ["online accounts","google account","microsoft account","nextcloud","accounts"]),
 ("system", "System", "ℹ️", ["system","about","about this pc","hostname","device name","software updates","secure shell","os version","hardware info"]),
 ("color", "Color", "🌈", ["color","color profile","icc","calibration"]),
 ("wellbeing", "Wellbeing", "🧘", ["wellbeing","screen time","break reminders","eye strain"]),
 ("wwan", "Mobile Network", "📱", ["wwan","mobile network","cellular","sim","lte"]),
 ("wacom", "Wacom Tablet", "✏️", ["wacom","tablet","stylus","pen"]),
]
ACTIONS = [  # (slug, title, icon, keywords, body)
 ("settings", "All Settings", "⚙️", ["settings","system settings","preferences","control center","gnome settings"], "exec gnome-control-center"),
 ("lock-screen", "Lock Screen", "🔐", ["lock","lock screen","lock computer","afk"], "exec loginctl lock-session"),
 ("log-out", "Log Out", "🚪", ["log out","logout","sign out","end session"], "exec gnome-session-quit --logout"),
 ("restart", "Restart", "🔁", ["restart","reboot"], "exec gnome-session-quit --reboot"),
 ("shut-down", "Shut Down", "⏻", ["shut down","shutdown","power off","turn off"], "exec gnome-session-quit --power-off"),
 ("suspend", "Suspend", "🌙", ["suspend","sleep","standby"], "exec systemctl suspend"),
 ("extensions", "Extensions", "🧩", ["extensions","gnome extensions","extension manager","shell extensions"], "exec gnome-extensions-app"),
 ("bluetooth-on", "Bluetooth On", "🟢", ["bluetooth on","enable bluetooth","turn on bluetooth","bt on"], "rfkill unblock bluetooth && notify-send 'Bluetooth' 'Radio unblocked'"),
 ("bluetooth-off", "Bluetooth Off", "🔴", ["bluetooth off","disable bluetooth","turn off bluetooth","bt off"], "rfkill block bluetooth && notify-send 'Bluetooth' 'Radio blocked'"),
 ("wifi-on", "Wi-Fi On", "🟢", ["wifi on","enable wifi","turn on wifi","wireless on"], "nmcli radio wifi on && notify-send 'Wi-Fi' 'Radio on'"),
 ("wifi-off", "Wi-Fi Off", "🔴", ["wifi off","disable wifi","turn off wifi","wireless off"], "nmcli radio wifi off && notify-send 'Wi-Fi' 'Radio off'"),
 ("airplane-toggle", "Airplane Mode (toggle)", "✈️", ["airplane","airplane mode","flight mode","all radios"], "if rfkill list | grep -q 'Soft blocked: yes'; then rfkill unblock all; notify-send 'Airplane mode' 'Off'; else rfkill block all; notify-send 'Airplane mode' 'On'; fi"),
 ("bluetooth-devices", "Bluetooth Devices (list)", "📋", ["bluetooth devices","paired devices","connected devices","bt list"], "bluetoothctl devices 2>/dev/null | sed 's/^Device //' | sort > /tmp/bt-devices.txt; [ -s /tmp/bt-devices.txt ] || echo 'No Bluetooth adapter / no paired devices' > /tmp/bt-devices.txt; cat /tmp/bt-devices.txt"),
 ("wifi-networks", "Wi-Fi Networks (list)", "📋", ["wifi list","wifi networks","available networks","scan wifi"], "nmcli -f SSID,SIGNAL,SECURITY dev wifi list 2>&1 | head -25"),
]
HEAD = "#!/bin/bash\n# @vicinae.schemaVersion 1\n# @vicinae.title {title}\n# @vicinae.mode {mode}\n# @vicinae.icon {icon}\n# @vicinae.keywords {kw}\n# @vicinae.packageName {pkg}\n# GENERATED by gen-settings.py, do not edit by hand.\nexport PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin\"\n"
def write(name, title, icon, kw, pkg, body, mode="silent"):
    p = os.path.join(OUT, name + ".sh")
    open(p, "w").write(HEAD.format(title=title, mode=mode, icon=icon, kw=json.dumps(kw), pkg=pkg) + body + "\n")
    os.chmod(p, os.stat(p).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
for panel, title, icon, kw, in PANELS:
    write("settings-" + panel, title, icon, kw + ["settings"], "Settings", f"exec gnome-control-center {panel}")
for slug, title, icon, kw, body in ACTIONS:
    mode = "fullOutput" if "(list)" in title else "silent"
    write("system-" + slug, title, icon, kw, "System", body, mode)
print(f"wrote {len(PANELS)} panel + {len(ACTIONS)} action commands to {OUT}")
