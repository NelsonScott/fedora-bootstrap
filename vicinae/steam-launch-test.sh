#!/bin/bash
# Exercises steam-launch against a fake flatpak + fake Steam logs. No real Steam involved.
set -u
T=$(mktemp -d /tmp/steam-launch-test.XXXX); HERE=$(dirname "$(readlink -f "$0")")
mkdir -p "$T/steam/logs"; FAIL=0
cat > "$T/flatpak" <<'F'
#!/bin/bash
S=$STEAM_LAUNCH_TESTDIR
echo "flatpak $*" >> "$S/calls"
case "$1" in
  ps) [ -f "$S/running" ] && echo com.valvesoftware.Steam ;;
  kill) rm -f "$S/running"; echo "killed" >> "$S/calls" ;;
  run) [ -f "$S/react" ] && { sleep 1; cat "$S/react" >> "$S/steam/logs/$(cat "$S/react.file")"; } ;;
esac
F
chmod +x "$T/flatpak"
run_case(){ # name running? hidden-state react-file react-line args...
  local name=$1 running=$2 hidden=$3 rfile=$4 rline=$5; shift 5
  rm -f "$T/running" "$T/react" "$T/react.file" "$T/calls" "$T/log"
  [ "$running" = 1 ] && touch "$T/running"
  printf '[2000-01-01 00:00:00] SP Desktop_uid0-'"'"'Steam'"'"': WasHidden %s: (0, 0) 1x1\n' "$hidden" > "$T/steam/logs/webhelper.txt"
  : > "$T/steam/logs/content_log.txt"
  if [ -n "$rline" ]; then printf '[%s] %s\n' "$(date -d '+2 seconds' '+%Y-%m-%d %H:%M:%S')" "$rline" > "$T/react"; echo "$rfile" > "$T/react.file"; fi
  STEAM_LAUNCH_TESTDIR=$T STEAM_LAUNCH_FLATPAK=$T/flatpak STEAM_LAUNCH_STEAMDIR=$T/steam \
  STEAM_LAUNCH_LOG=$T/log STEAM_LAUNCH_WAIT=3 STEAM_LAUNCH_WAIT_GAME=3 STEAM_LAUNCH_GAME_RUNNING=${GAME:-0} \
    "$HERE/steam-launch" "$@"
  for _ in $(seq 1 25); do grep -q '^.* done:' "$T/log" 2>/dev/null && break; sleep 0.5; done
  echo "== $name"; sed 's/^[0-9-]* [0-9:]* /   /' "$T/log"
}
expect(){ if grep -q "$1" "$T/log"; then echo "   ok   $2"; else echo "   FAIL $2"; FAIL=1; fi; }
expect_calls(){ if [ "$(grep -c '^killed' "$T/calls" 2>/dev/null)" = "$1" ]; then echo "   ok   kills=$1"; else echo "   FAIL kills!=$1"; FAIL=1; fi; }

run_case "A: client up, window hidden, reacts by showing it" 1 1 webhelper.txt "SP Desktop_uid0-'Steam': WasHidden 0: (0, 0) 1x1"
expect "done: main window shown" "no recovery when the client reacts"; expect_calls 0
run_case "B: client up, window hidden, swallows the launch (tonight's wedge)" 1 1 "" ""
expect "swallowed the launch" "wedge detected"; expect "cold start" "cold start after kill"; expect_calls 1
run_case "C: client up, window already visible" 1 0 "" ""
expect "already visible" "visible window is left alone"; expect_calls 0
run_case "D: no client running" 0 1 "" ""
expect "done: cold start (no client" "plain cold start"; expect_calls 0
run_case "E: game launch reaches App Running" 1 1 content_log.txt "AppID 1145350 state changed : Fully Installed,App Running," steam://rungameid/1145350
expect "done: game 1145350 started" "game start detected"; expect_calls 0
run_case "F: game launch swallowed" 1 1 "" "" steam://rungameid/1145350
expect "swallowed the game launch" "wedge on game launch"; expect_calls 1
GAME=1 run_case "G: window hidden, no reaction, but a game is running" 1 1 "" ""
expect "a game is running, not touching" "never kills Steam under a running game"; expect_calls 0
rm -rf "$T"; echo; [ $FAIL = 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
