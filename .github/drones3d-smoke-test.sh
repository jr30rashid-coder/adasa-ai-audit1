#!/usr/bin/env bash
set -euo pipefail

apk='deliverable/Drones3D-v1.0.0-rc1-release.apk'
package='com.aistudio.drones3d.kqvmrx'
activity='com.aistudio.drones3d.kqvmrx/com.example.MainActivity'

adb wait-for-device
adb install -r "$apk"
adb logcat -c
launch="$(adb shell am start -W -n "$activity" | tr -d '\r')"
printf '%s\n' "$launch"
if ! grep -q 'Status: ok' <<< "$launch"; then
  echo '::error::Android did not report a successful activity launch.'
  exit 1
fi
# Allow the initial Compose UI and OpenGL setup to settle before checking for a crash.
sleep 8
pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
if [ -z "$pid" ]; then
  echo '::error::Application process is no longer running after launch.'
  adb logcat -d -s AndroidRuntime:E | tail -n 80
  exit 1
fi
adb logcat -d -s AndroidRuntime:E > "$RUNNER_TEMP/android-runtime.log"
if grep -q 'FATAL EXCEPTION' "$RUNNER_TEMP/android-runtime.log"; then
  echo '::error::A fatal Android runtime exception occurred during launch.'
  tail -n 80 "$RUNNER_TEMP/android-runtime.log"
  exit 1
fi
mkdir -p smoke-test
adb exec-out screencap -p > smoke-test/screenshot.png
printf 'Installed and launched %s on Android 11 (API 30); process %s remained running.\n' "$package" "$pid" > smoke-test/result.txt
echo '::notice::APK installed and launched successfully on Android 11; the app process remained running.'
