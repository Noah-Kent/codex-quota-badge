#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd -P)
APP_PATH="$ROOT_DIR/dist/CodexQuotaBadge.app"
DMG_PATH="$ROOT_DIR/dist/CodexQuotaBadge-preview.dmg"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/CodexQuotaBadge"
ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"

test -x "$EXECUTABLE_PATH"
test -f "$PLIST_PATH"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST_PATH")" = "com.codexquotabadge.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST_PATH")" = "AppIcon"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST_PATH")" = "true"
test -f "$ICON_PATH"
/usr/bin/codesign --verify --strict "$APP_PATH"
test -f "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null
