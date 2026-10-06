#!/bin/zsh
# Build a release APK with the frame probe + auto tour, run it on the phone and
# print per-screen frame stats.   tools/perf/run_tour.sh <label> [extra flutter build args]
set -e
LABEL=${1:-run}; shift || true
cd "$(dirname "$0")/../.."
export PATH="$HOME/development/flutter/bin:$PATH"
ADB=~/Library/Android/sdk/platform-tools/adb
export ANDROID_SERIAL=${ANDROID_SERIAL:-f13ad825}
OUT=build/perf; mkdir -p $OUT
flutter build apk --release --target-platform android-arm64 --dart-define=PERF=true --dart-define=PERF_TOUR=true "$@" 2>&1 | tail -1
$ADB install -r build/app/outputs/flutter-apk/app-release.apk | tail -1
$ADB shell am force-stop com.setir.bloom
$ADB logcat -c
$ADB shell monkey -p com.setir.bloom -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
# The tour takes about a minute; stop when it says done.
for i in {1..60}; do sleep 2; $ADB logcat -d -s flutter | grep -q "tour: done" && break; done
$ADB logcat -d -s flutter | grep "\[perf\]" | sed 's/^.*\[perf\] //' > $OUT/$LABEL.log
python3 tools/perf/summary.py $OUT/$LABEL.log
