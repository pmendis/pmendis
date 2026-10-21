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
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || continue
  adb shell cat /sdcard/ui.xml > "$OUT/ui.xml" 2>/dev/null || continue
  if grep -q -E "Search places|map server|Loading map|could not start" "$OUT/ui.xml"; then
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
echo "== App log (flutter, crashes, plugin errors):"
grep -E "flutter|Lanka Maps|AndroidRuntime|FATAL|$PKG|MissingPlugin|Exception" "$OUT/logcat.txt" | tail -150

if [[ "$started" != true ]]; then
  echo "FAIL: the app did not get past the splash screen within 90 seconds"
  exit 1
fi
if grep -q "could not start" "$OUT/ui.xml"; then
  echo "FAIL: the app showed its startup error screen"
  exit 1
fi
echo "OK: the app started and showed its UI"
