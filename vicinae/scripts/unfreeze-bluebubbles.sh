#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Unfreeze BlueBubbles
# @vicinae.mode silent
# @vicinae.icon 💬
# @vicinae.keywords ["bluebubbles","unfreeze","frozen","imessage","bbfix","stuck"]
# @vicinae.packageName Fixes
# BlueBubbles window stopped updating (Flutter 3.47 + NVIDIA shared-frame bug)? Nudge it 1px so
# Flutter rebuilds the shared frame texture. Same as `bbfix` in a terminal.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
exec "$HOME/.local/bin/bbfix"
