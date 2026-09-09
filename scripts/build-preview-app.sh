#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd -P)
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/CodexQuotaBadge.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/CodexQuotaBadge"

swift build -c release --product CodexQuotaBadge
mkdir -p "$APP_PATH/Contents/MacOS"
cp "$ROOT_DIR/.build/release/CodexQuotaBadge" "$EXECUTABLE_PATH"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_PATH"

printf 'Created ad-hoc signed preview app: %s\n' "$APP_PATH"
