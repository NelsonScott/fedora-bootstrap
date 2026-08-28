# Shared helper: send a key chord through ydotoold (user service from the dictation setup).
# keyd ignores ydotool's virtual keyboard (ids -2333:6666), so these are REAL keycodes:
# 125=LeftMeta(Super) 29=Ctrl 56=Alt 42=Shift 35=h 5=4 19=r 105/106/103/108=Left/Right/Up/Down
chord() {  # chord 29 125 35  -> press all in order, release in reverse
  local down="" up="" k
  for k in "$@"; do down+="$k:1 "; done
  for ((i=$#; i>0; i--)); do up+="${!i}:0 "; done
  ydotool key $down$up
}
sleep 0.25   # let the Vicinae window close and focus return to the previous window
