#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Hide All Windows
# @vicinae.mode silent
# @vicinae.icon 🫥
# @vicinae.keywords ["corners","hide","hide windows","show desktop","desktop","minimize all","clear screen","hide everything"]
# @vicinae.packageName Desktop
source "$(dirname "$0")/_keys.sh"
# show-desktop is bound to Ctrl+Super+Alt+H by vicinae/install.sh
chord 29 125 56 35
