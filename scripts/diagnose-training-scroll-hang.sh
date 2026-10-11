#!/bin/zsh
# Reproduces the Training-tab main-thread hang introduced by c3c04553 (spec 084 card B) and
# removed for the recording state by spec 090. See docs/diagnose/training-scroll-hang-2026-10-11.md.
#
# Drives a built MeetPR-DemoStudent simulator app: Training -> Start first set -> log set 1
# (the rest timer starts) -> scroll. Red = the app's main thread stays above 80% CPU on two
# samples three seconds apart. Prints one line per iteration and a RESULT line.
#
# usage: SIM=<simulator udid> AXE=<path to the axe binary> scripts/diagnose-training-scroll-hang.sh <MeetPR.app> [iterations]
#   AXE ships inside XcodeBuildMCP (.../xcodebuildmcp/bundled/axe).
set -u
D=${SIM:?set SIM to a booted simulator udid}
AXE=${AXE:?set AXE to the axe binary}
APP=${1:?path to the built MeetPR.app}; N=${2:-6}
btn(){ "$AXE" describe-ui --udid "$D" 2>/dev/null | python3 -c "
import sys,json
t=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit()
def walk(n,o):
    if isinstance(n,list):
        for x in n: walk(x,o)
        return
    l=n.get('AXLabel') or ''; f=n.get('frame',{})
    if n.get('type')=='Button' and l.startswith(t) and f.get('height',0)>0: o.append((round(f['x']+f['width']/2),round(f['y']+f['height']/2)))
    walk(n.get('children',[]),o)
o=[]; walk(d,o); print(o[0][0],o[0][1]) if o else print('')" "$1"; }
tap(){ local p; p=$(btn "$1"); [ -z "$p" ] && return 1; "$AXE" tap -x ${p% *} -y ${p#* } --udid "$D" >/dev/null 2>&1; sleep ${2:-2.5}; }
xcrun simctl terminate "$D" com.meetpr.app 2>/dev/null; xcrun simctl install "$D" "$APP" || exit 2
hang=0; ok=0; skip=0
for i in $(seq 1 "$N"); do
  xcrun simctl terminate "$D" com.meetpr.app 2>/dev/null; sleep 1
  xcrun simctl launch "$D" com.meetpr.app -AppleLanguages "(en)" -AppleLocale en_US -meetpr.appearance light >/dev/null 2>&1; sleep 5
  tap "Training" 3 || { echo "[$i] skip: no Training tab"; skip=$((skip+1)); continue; }
  tap "Start first set" 2.5
  tap "Log this set" 3 || { echo "[$i] skip: no Log this set"; skip=$((skip+1)); continue; }
  tap "Complete set" 4 || { echo "[$i] skip: no Complete set"; skip=$((skip+1)); continue; }
  tap "Got it" 2
  X=$([ $((i % 2)) -eq 0 ] && echo 12 || echo 210)
  for s in 1 2 3 4 5 6; do "$AXE" swipe --start-x $X --start-y 650 --end-x $X --end-y 250 --udid "$D" >/dev/null 2>&1; sleep 0.6; done
  sleep 3
  P=$(pgrep -f "$D.*MeetPR.app/MeetPR" | head -1)
  c1=$(ps -o %cpu= -p "$P" | tr -d ' '); sleep 3; c2=$(ps -o %cpu= -p "$P" | tr -d ' ')
  if python3 -c "import sys; sys.exit(0 if min(float('$c1'),float('$c2'))>80 else 1)"; then hang=$((hang+1)); r=HANG; else ok=$((ok+1)); r=ok; fi
  echo "[$i] swipe-x=$X cpu=$c1/$c2 => $r"
done
echo "RESULT hang=$hang ok=$ok skipped=$skip of $N"
[ "$hang" -eq 0 ]
