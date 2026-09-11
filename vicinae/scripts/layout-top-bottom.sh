#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Layout: Top / Bottom halves · 22" portrait
# @vicinae.mode silent
# @vicinae.icon ⬒
# @vicinae.keywords ["layout","top bottom","halves","stacked","portrait","vertical","second","tiling","grid"]
# @vicinae.packageName Tiling Layout
# @vicinae.argument1 { "type": "text", "placeholder": "monitor: second 22in portrait (default) - type main for the 32in", "optional": true }
source "$(dirname "$0")/_layout.sh"
case "${1,,}" in main|1|32|big|primary) mon=0 ;; *) mon=1 ;; esac
set_layout "Top / Bottom" "$mon"
