#!/usr/bin/env bash
# Captures Play Store screenshots of the debug build on an already-booted emulator.
# Used by .github/workflows/screenshots.yml. Writes PNGs, a disclosure video, UI dumps and logs to $1.
set -uo pipefail

PKG=dev.natya.opendictate
OUT=${1:-screenshots}
mkdir -p "$OUT"

SIZE=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1)
W=${SIZE%x*}
H=${SIZE#*x}
DPI=$(adb shell wm density | grep -o '[0-9]*' | tail -1)
X=$((W / 2))
echo "screen ${W}x${H} @ ${DPI}dpi"

dp() { python3 -c "print(int($1 * $DPI / 160 + 0.5))"; }   # same rounding as BubbleView.dp()
shot() { sleep "${2:-1.5}"; adb exec-out screencap -p > "$OUT/$1.png" && echo "shot $1"; }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && adb pull /sdcard/ui.xml "$OUT/$1.xml" >/dev/null 2>&1; }
to_bottom() { for _ in 1 2 3 4 5 6 7 8; do adb shell input swipe "$X" $((H * 3 / 4)) "$X" $((H / 6)) 120; done; sleep 1; }
msg_compose() { adb shell am start -W -a android.intent.action.SENDTO -d sms:5550123 >/dev/null 2>&1; sleep 4; }

# center FILE CLASS [TEXT] [PACKAGE]: prints "x y" at the centre of the last matching node in a UI dump.
center() {
  python3 - "$@" <<'PY'
import re, sys, xml.etree.ElementTree as ET
path, cls = sys.argv[1], sys.argv[2]
text = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3] else None
pkg = sys.argv[4] if len(sys.argv) > 4 else None
nodes = [n for n in ET.parse(path).iter("node")
         if n.get("class") == cls
         and (text is None or text in (n.get("text") or "").lower())
         and (pkg is None or n.get("package") == pkg)]
if not nodes:
    sys.exit(1)
x1, y1, x2, y2 = map(int, re.findall(r"\d+", nodes[-1].get("bounds")))
print((x1 + x2) // 2, (y1 + y2) // 2)
PY
}

# Taps the centre of the idle pill, using the y position that the debug build logs.
pill() {
  local y
  y=$(adb logcat -d -s OpenDictate:D | sed -n 's/.*pill y=\([0-9]*\).*/\1/p' | tail -1)
  [ -n "$y" ] || { echo "pill not shown"; return 1; }
  adb shell input tap $((W - $(dp 10) - $(dp 40) / 2)) $((y + $(dp 40) / 2))
}

adb install -r app/build/outputs/apk/debug/app-debug.apk

# Clean status bar, and keep the soft keyboard visible.
adb shell settings put global sysui_demo_allowed 1
for c in "enter" "clock -e hhmm 0930" "battery -e level 100 -e plugged false" \
         "network -e wifi show -e level 4" "network -e mobile show -e datatype none -e level 4" \
         "notifications -e visible false"; do
  # shellcheck disable=SC2086 # $c holds several arguments on purpose
  adb shell am broadcast -a com.android.systemui.demo -e command $c >/dev/null
done
adb shell settings put secure show_ime_with_hard_keyboard 1

# App state: a placeholder Groq key (the field only shows dots) and the mic permission.
printf '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>\n<map>\n    <string name="key">gsk_placeholder</string>\n</map>\n' \
  | adb shell "run-as $PKG sh -c 'mkdir -p shared_prefs && cat > shared_prefs/cfg.xml'"
adb shell pm grant $PKG android.permission.RECORD_AUDIO

# --- Service off: record the disclosure flow and find tap targets. uiautomator is only used here,
# because it can suspend other accessibility services while it runs.
adb shell am start -W -n $PKG/.MainActivity >/dev/null
sleep 2
dump main-top
adb shell screenrecord --time-limit 25 /sdcard/disclosure.mp4 &
REC=$!
sleep 2
if xy=$(center "$OUT/main-top.xml" android.widget.Button "turn on opendictate"); then
  adb shell input tap $xy
  shot 00-disclosure 3
  dump disclosure
  if xy=$(center "$OUT/disclosure.xml" android.widget.Button "agree"); then
    sleep 3
    adb shell input tap $xy
    shot 00-accessibility-settings 4
  fi
fi
wait $REC
adb pull /sdcard/disclosure.mp4 "$OUT/" >/dev/null 2>&1 || echo "no disclosure video"

adb shell am start -W -n $PKG/.MainActivity -f 0x10008000 >/dev/null
sleep 2
to_bottom
dump main-bottom
TRY=$(center "$OUT/main-bottom.xml" android.widget.EditText "" $PKG) || TRY=""

adb shell input keyevent KEYCODE_HOME
msg_compose
shot msg-raw 0
dump msg
MSG_PKG=$(grep -o 'package="[^"]*messaging[^"]*"' "$OUT/msg.xml" 2>/dev/null | head -1 | cut -d'"' -f2)
MSG=""
[ -n "$MSG_PKG" ] && { MSG=$(center "$OUT/msg.xml" android.widget.EditText "" "$MSG_PKG") || MSG=""; }
echo "try-it field: ${TRY:-none}  messages field: ${MSG:-none} (${MSG_PKG:-no messaging app})"

# --- Service on.
adb shell settings put secure enabled_accessibility_services $PKG/$PKG.FlowService
adb shell settings put secure accessibility_enabled 1
sleep 3

adb shell am start -W -n $PKG/.MainActivity -f 0x10008000 >/dev/null
shot 01-settings 2.5

if [ -n "$TRY" ]; then
  to_bottom
  adb logcat -c
  adb shell input tap $TRY
  sleep 2.5
  adb shell input text "Running%s10%sminutes%slate,%ssave%sme%sa%sseat"
  shot 02-try-it 2
  if pill; then
    shot 03-recording 1.8
    pill || true   # stop; Groq rejects the placeholder key, which doesn't matter here
    sleep 4
  fi
fi

if [ -n "$MSG" ]; then
  adb shell input keyevent KEYCODE_HOME
  msg_compose
  adb logcat -c
  adb shell input tap $MSG
  sleep 2.5
  adb shell input text "On%smy%sway,%sbe%sthere%sin%s10"
  shot 04-messages 2
  if pill; then
    shot 05-messages-recording 1.8
    pill || true
    sleep 4
  fi
fi

adb shell input keyevent KEYCODE_HOME
adb shell cmd uimode night yes
adb shell am start -W -n $PKG/.MainActivity -f 0x10008000 >/dev/null
shot 06-settings-dark 3
adb shell cmd uimode night no

adb logcat -d -s OpenDictate:D AndroidRuntime:E > "$OUT/logcat.txt"
ls -la "$OUT"
