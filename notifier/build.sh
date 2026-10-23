#!/bin/bash
# Builds the notifier app: build.sh <source dir with notify.applescript and icon.icns> <output .app path>
set -euo pipefail

SRC=$1; APP=$2
rm -rf "$APP"
osacompile -o "$APP" "$SRC/notify.applescript"
# Newer applets carry their icon in Assets.car, which would win over applet.icns.
rm -f "$APP/Contents/Resources/Assets.car"
cp "$SRC/icon.icns" "$APP/Contents/Resources/applet.icns"
PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "io.github.cristopheer96.ai-usage-meter" "$PLIST"
plutil -replace CFBundleName -string "AI Usage Meter" "$PLIST"
plutil -remove CFBundleIconName "$PLIST" 2>/dev/null || true
plutil -replace LSUIElement -bool true "$PLIST"
codesign --force --sign - "$APP" >/dev/null 2>&1
touch "$APP"
