#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Layout: 1/3 + 2/3 · small left, big right · 32" main
# @vicinae.mode silent
# @vicinae.icon ◨
# @vicinae.keywords ["layout","33 67","third","two columns","left small","tiling","grid","main"]
# @vicinae.packageName Tiling Layout
# @vicinae.argument1 { "type": "text", "placeholder": "monitor: main 32in (default) - type second for the 22in", "optional": true }
source "$(dirname "$0")/_layout.sh"
case "${1,,}" in second|2|22|small|portrait) mon=1 ;; *) mon=0 ;; esac
set_layout "1/3 + 2/3" "$mon"
