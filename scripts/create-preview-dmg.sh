#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd -P)
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/CodexQuotaBadge.app"
DMG_PATH="$DIST_DIR/CodexQuotaBadge-preview.dmg"
mkdir -p "$DIST_DIR"
STAGING_DIR=$(mktemp -d "$DIST_DIR/.dmg-staging.XXXXXX")

cleanup() {
    /bin/rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

bash "$ROOT_DIR/scripts/build-preview-app.sh"
mkdir -p "$STAGING_DIR"
/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/CodexQuotaBadge.app"
/usr/bin/hdiutil create -ov -volname "Codex Quota Badge" -srcfolder "$STAGING_DIR" -format UDZO "$DMG_PATH" >/dev/null

printf 'Created ad-hoc signed preview disk image: %s\n' "$DMG_PATH"
