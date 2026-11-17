#!/usr/bin/env bash
# Records the video Google Play asks for in the Accessibility API declaration: opening the app, the in-app
# disclosure, declining and seeing it again, consenting and granting the permission in Settings, then dictation
# into Google Messages. Burns in captions afterwards. Used by .github/workflows/demo-video.yml, which feeds the
# emulator microphone from a PulseAudio null sink called "vmic". Needs GROQ_API_KEY for real transcription.
set -uo pipefail

PKG=dev.natya.opendictate
OUT=${1:-demo}
SPEECH=scripts/demo-speech.wav
mkdir -p "$OUT/captions" "$OUT/frames"
: > "$OUT/captions.tsv"

SIZE=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1)
W=${SIZE%x*}
H=${SIZE#*x}
DPI=$(adb shell wm density | grep -o '[0-9]*' | tail -1)
echo "screen ${W}x${H} @ ${DPI}dpi"

now() { python3 -c 'import time; print(f"{time.time():.2f}")'; }
dp() { python3 -c "print(int($1 * $DPI / 160 + 0.5))"; }   # same rounding as BubbleView.dp()
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && adb pull /sdcard/ui.xml "$OUT/$1.xml" >/dev/null 2>&1; }
msg_compose() { adb shell am start -W -a android.intent.action.SENDTO -d sms:5550123 >/dev/null 2>&1; sleep 4; }
caption() { printf '%s\t%s\n' "$(python3 -c "import time; print(f'{time.time() - $T0:.2f}')")" "$1" >> "$OUT/captions.tsv"; }

# center FILE CLASS [TEXT] [PACKAGE]: "x y" at the centre of the last matching node ("*" matches any class).
center() {
  python3 - "$@" <<'PY'
import re, sys, xml.etree.ElementTree as ET
path, cls = sys.argv[1], sys.argv[2]
text = (sys.argv[3] if len(sys.argv) > 3 else "").lower() or None
pkg = (sys.argv[4] if len(sys.argv) > 4 else "") or None
nodes = [n for n in ET.parse(path).iter("node")
         if (cls == "*" or n.get("class") == cls)
         and (text is None or text in (n.get("text") or "").lower())
         and (pkg is None or n.get("package") == pkg)]
if not nodes:
    sys.exit(1)
x1, y1, x2, y2 = map(int, re.findall(r"\d+", nodes[-1].get("bounds")))
print((x1 + x2) // 2, (y1 + y2) // 2)
PY
}

# tap_text NAME CLASS TEXT: dumps the screen to NAME.xml and taps the matching node; leaves its centre in XY.
# Only safe while OpenDictate's service is off: uiautomator can suspend other accessibility services.
XY=""
tap_text() {
  if dump "$1" && XY=$(center "$OUT/$1.xml" "$2" "$3"); then
    adb shell input tap $XY
  else
    echo "not found on screen '$1': $2 '$3'"
    return 1
  fi
}

# Taps the centre of the idle pill, using the y position that the debug build logs.
pill() {
  local y
  y=$(adb logcat -d -s OpenDictate:D | sed -n 's/.*pill y=\([0-9]*\).*/\1/p' | tail -1)
  [ -n "$y" ] || { echo "pill not shown"; return 1; }
  adb shell input tap $((W - $(dp 10) - $(dp 40) / 2)) $((y + $(dp 40) / 2))
}

# Voice for the dictation step: the emulator's gRPC injectAudio API (stubs compiled from the emulator's own
# proto), with the PulseAudio null sink as a fallback.
EMU=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}/emulator
"$EMU/emulator" -version 2>/dev/null | head -1
PROTO=$(find "$EMU" -name emulator_controller.proto 2>/dev/null | head -1)
GRPC_PY=/tmp/grpc-venv/bin/python
WKT=$("$GRPC_PY" -c 'import grpc_tools, os; print(os.path.join(os.path.dirname(grpc_tools.__file__), "_proto"))' 2>/dev/null)
mkdir -p "$OUT/stubs"
if [ -n "$PROTO" ] && "$GRPC_PY" -m grpc_tools.protoc -I "$(dirname "$PROTO")" -I "$WKT" \
     --python_out="$OUT/stubs" --grpc_python_out="$OUT/stubs" "$PROTO"; then
  echo "gRPC stubs compiled from $PROTO"
else
  echo "could not compile gRPC stubs (proto: ${PROTO:-not found})"
fi
ffmpeg -y -loglevel error -i "$SPEECH" -af apad=pad_dur=0.4 -ar 44100 -ac 1 -f s16le "$OUT/speech.pcm"
speak() {
  pactl list short source-outputs | sed 's/^/  pulse capture stream: /'
  if "$GRPC_PY" scripts/inject_audio.py "$OUT/stubs" "$OUT/speech.pcm" 8554; then return 0; fi
  echo "gRPC injection failed; falling back to the PulseAudio sink"
  paplay --device=vmic "$SPEECH" || echo "paplay failed"
}

adb install -r app/build/outputs/apk/debug/app-debug.apk

# Clean status bar, and keep the soft keyboard visible.
adb shell settings put global sysui_demo_allowed 1
for c in "enter" "clock -e hhmm 0930" "battery -e level 100 -e plugged false" \
         "network -e wifi show -e level 4 -e fully true" "network -e mobile show -e datatype none -e level 4" \
         "notifications -e visible false"; do
  # shellcheck disable=SC2086 # $c holds several arguments on purpose
  adb shell am broadcast -a com.android.systemui.demo -e command $c >/dev/null
done
adb shell settings put secure show_ime_with_hard_keyboard 1

KEY=${GROQ_API_KEY:-}
[ -n "$KEY" ] || echo "GROQ_API_KEY is not set: the dictation step will only show the button"
printf '<?xml version="1.0" encoding="utf-8" standalone="yes" ?>\n<map>\n    <string name="key">%s</string>\n</map>\n' \
  "${KEY:-gsk_placeholder}" | adb shell "run-as $PKG sh -c 'mkdir -p shared_prefs && cat > shared_prefs/cfg.xml'"
adb shell pm grant $PKG android.permission.RECORD_AUDIO

# Find the Messages compose box now, while the service is still off.
msg_compose
dump msg
MSG_PKG=$(grep -o 'package="[^"]*messaging[^"]*"' "$OUT/msg.xml" 2>/dev/null | head -1 | cut -d'"' -f2)
MSG=""
[ -n "$MSG_PKG" ] && { MSG=$(center "$OUT/msg.xml" android.widget.EditText "" "$MSG_PKG") || MSG=""; }
echo "messages field: ${MSG:-none} (${MSG_PKG:-no messaging app})"
adb shell input keyevent KEYCODE_BACK
adb shell input keyevent KEYCODE_HOME
sleep 2

# ---------------------------------------------------------------- recording
adb shell screenrecord --bit-rate 8000000 --time-limit 175 /sdcard/demo.mp4 &
REC=$!
T0=$(now)
sleep 2

caption "Opening OpenDictate from the app drawer."
adb shell input swipe $((W / 2)) $((H * 3 / 4)) $((W / 2)) $((H / 4)) 300
sleep 2.5
tap_text drawer android.widget.TextView "opendictate"
sleep 4

caption "Accessibility is off. Tapping \"Turn on OpenDictate in Accessibility\" first shows the in-app disclosure."
sleep 2.5
tap_text main android.widget.Button "turn on opendictate"
TURN_ON=$XY
sleep 1.5
caption "The full disclosure: what the service reads, and what is sent to Groq."
sleep 9

caption "Not consenting: \"No thanks\" closes the disclosure. Nothing is turned on."
tap_text decline android.widget.Button "no thanks"
sleep 4
caption "Tapping \"Turn on\" again shows the same disclosure again."
[ -n "$TURN_ON" ] && adb shell input tap $TURN_ON
sleep 5

caption "Consenting: \"Agree\" opens Android's Accessibility settings."
tap_text consent android.widget.Button "agree"
sleep 4
caption "The user selects OpenDictate under Downloaded apps..."
tap_text a11y android.widget.TextView "opendictate"
sleep 3
caption "...and turns on \"Use OpenDictate\"."
tap_text service android.widget.TextView "use opendictate"
sleep 2.5
caption "Android asks to grant the Accessibility permission. The user taps Allow."
sleep 2.5
tap_text allow "*" "allow"
sleep 3

caption "Back in OpenDictate, the service is now on."
adb shell input keyevent KEYCODE_BACK
sleep 1
adb shell input keyevent KEYCODE_BACK
sleep 4

caption "Core feature: when a text field in another app is focused, the service shows a mic button above the keyboard."
adb shell input keyevent KEYCODE_HOME
sleep 1
msg_compose
adb logcat -c
[ -n "$MSG" ] && adb shell input tap $MSG
sleep 4
if [ -n "$KEY" ] && pill; then
  caption "Tap it and speak. It records only until the user taps it again."
  sleep 1
  speak
  sleep 0.8
  pill
  caption "The Accessibility service types the transcription into the focused field."
  sleep 9
else
  caption "Tap it and speak. The transcription is typed into the focused field."
  sleep 6
fi
caption "Audio goes only to Groq with the user's own API key, and each recording is deleted after transcription."
sleep 5

adb shell pkill -INT screenrecord
wait $REC
END=$(python3 -c "import time; print(f'{time.time() - $T0:.2f}')")
sleep 2
adb pull /sdcard/demo.mp4 "$OUT/demo-raw.mp4" >/dev/null || { echo "no recording"; exit 1; }

# Did dictation land in the field? (The service no longer matters, so uiautomator is fine here.)
dump final
python3 - "$OUT/final.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if n.get("class") == "android.widget.EditText":
        print("field text after dictation:", repr(n.get("text")))
PY
adb logcat -d -s OpenDictate:D AndroidRuntime:E > "$OUT/logcat.txt"

# ---------------------------------------------------------------- captions
# Pads a caption band above the screen and draws each caption from its timestamp until the next one.
# Each wrapped line is its own drawtext: newer ffmpeg draws a missing-glyph box at embedded line breaks.
N=$(python3 - "$OUT" "$END" <<'PY'
import pathlib, sys, textwrap
out, end = pathlib.Path(sys.argv[1]), float(sys.argv[2])
rows = [line.split("\t", 1) for line in (out / "captions.tsv").read_text().splitlines() if line]
font, band, size, step = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 260, 40, 54
parts, n = [f"[0:v]pad=iw:ih+{band}:0:{band}:color=0x111111[v0]"], 0
for i, (t, text) in enumerate(rows):
    start, stop = float(t), float(rows[i + 1][0]) if i + 1 < len(rows) else end
    lines = textwrap.wrap(text, 44)
    top = (band - (len(lines) * step - (step - size))) / 2
    for j, line in enumerate(lines):
        f = (out / "captions" / f"{i:02d}-{j}.txt").resolve()
        f.write_text(line)
        parts.append(f"[v{n}]drawtext=fontfile={font}:textfile={f}:fontcolor=white:fontsize={size}:"
                     f"x=(w-text_w)/2:y={top + j * step:.0f}:enable='between(t,{start:.2f},{stop:.2f})'[v{n + 1}]")
        n += 1
    (out / "frames" / "times.txt").open("a").write(f"{(start + stop) / 2:.2f}\n")
(out / "filter.txt").write_text(";\n".join(parts))
print(n)
PY
)
ffmpeg -y -loglevel error -i "$OUT/demo-raw.mp4" -filter_complex_script "$OUT/filter.txt" -map "[v$N]" \
  -r 30 -c:v libx264 -pix_fmt yuv420p -crf 20 -preset veryfast "$OUT/opendictate-accessibility-demo.mp4"

# One still per caption, for checking the video without watching it.
i=0
while read -r t; do
  ffmpeg -y -loglevel error -ss "$t" -i "$OUT/opendictate-accessibility-demo.mp4" -frames:v 1 -vf scale=432:-1 \
    "$OUT/frames/$(printf %02d $i).png"
  i=$((i + 1))
done < "$OUT/frames/times.txt"
ls -la "$OUT" "$OUT/frames"
