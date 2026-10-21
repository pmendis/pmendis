#!/usr/bin/env bash
# Installs the APK on a running emulator, launches it, and checks that the
# app gets past the splash screen. Prints the app's log either way.
#
# Usage: tool/android_smoke_test.sh path/to/app.apk
set -uo pipefail

APK="$1"
PKG=lk.lankamaps.lanka_maps
OUT="${OUT_DIR:-smoke-test}"
mkdir -p "$OUT"

adb install -r "$APK"
# Pre-grant permissions so system dialogs don't cover the app.
for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS; do
  adb shell pm grant "$PKG" "android.permission.$p" 2>/dev/null || true
done

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null

# The app has started once Flutter shows one of its own screens. Without a
# map server it shows the "Cannot reach the map server" screen.
started=false
for _ in $(seq 1 30); do
  sleep 3
  # Fails ("could not get idle state") while a spinner is animating; the
  # app log below is the more reliable signal.
  adb shell uiautomator dump /sdcard/ui.xml >"$OUT/uiautomator.txt" 2>&1 || true
  adb shell cat /sdcard/ui.xml > "$OUT/ui.xml" 2>/dev/null || continue
  if adb logcat -d -s flutter | grep -q "Lanka Maps: first frame drawn" ||
     grep -q -E "Search places|map server|Loading map|could not start" "$OUT/ui.xml" 2>/dev/null; then
    started=true
    break
  fi
done

adb exec-out screencap -p > "$OUT/screen.png" || true
adb logcat -d > "$OUT/logcat.txt" || true
pid=$(adb shell pidof "$PKG" | tr -d '\r')

echo "== App process id: ${pid:-not running}"
echo "== Screen text:"
grep -o -E '(text|content-desc)="[^"]+"' "$OUT/ui.xml" 2>/dev/null | sort -u | head -40
echo "== uiautomator: $(tail -1 "$OUT/uiautomator.txt" 2>/dev/null)"
echo "== Screenshot colours (a splash screen is nearly one colour):"
python3 - "$OUT/screen.png" <<'PY' || true
import sys, zlib, struct, collections
data = open(sys.argv[1], 'rb').read()
w, h = struct.unpack('>II', data[16:24])
raw = b''.join(data[i + 8:i + 8 + struct.unpack('>I', data[i:i + 4])[0]]
              for i in [p for p in range(8, len(data)) if data[p + 4:p + 8] == b'IDAT'])
print(f"{w}x{h}, {len(set(zlib.decompress(raw)[::997]))} distinct sampled byte values")
PY
echo "== Flutter log:"
adb logcat -d -s flutter | tail -80
echo "== Everything the app process logged:"
if [[ -n "$pid" ]]; then adb logcat -d --pid="$pid" | tail -150; fi
echo "== Crashes:"
grep -E "FATAL|AndroidRuntime: (FATAL|Process: $PKG)" "$OUT/logcat.txt" | tail -40

if [[ "$started" != true ]]; then
  echo "FAIL: the app did not get past the splash screen within 90 seconds"
  exit 1
fi
if grep -q "could not start" "$OUT/ui.xml"; then
  echo "FAIL: the app showed its startup error screen"
  exit 1
fi
echo "OK: the app started and showed its UI"
