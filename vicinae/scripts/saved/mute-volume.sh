#!/bin/bash
# @vicinae.schemaVersion 1
# @vicinae.title Mute Volume
# @vicinae.mode silent
# @vicinae.icon 🧩
# @vicinae.keywords ["audio off", "mute", "mute the volume", "silence", "unmute", "volume"]
# @vicinae.packageName Saved
# Saved from Ask Claude. Question: mute the volume
# Toggles system audio mute using wpctl
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
