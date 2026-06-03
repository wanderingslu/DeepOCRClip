#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/Resources/Info.plist")"
APP_DIR="$ROOT_DIR/dist/DeepOCRClip.app"
DMG_ROOT="$ROOT_DIR/dist/dmg-root"
DMG_PATH="$ROOT_DIR/dist/DeepOCRClip-$VERSION.dmg"
VOLUME_NAME="DeepOCRClip $VERSION"

"$ROOT_DIR/scripts/build_app.sh" release >/dev/null

rm -rf "$DMG_ROOT"
rm -f "$DMG_PATH"
mkdir -p "$DMG_ROOT"

ditto "$APP_DIR" "$DMG_ROOT/DeepOCRClip.app"
ln -s /Applications "$DMG_ROOT/Applications"
xattr -cr "$DMG_ROOT" 2>/dev/null || true

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
