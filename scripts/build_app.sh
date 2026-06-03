#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"

case "$CONFIGURATION" in
    debug|release) ;;
    *)
        echo "Usage: scripts/build_app.sh [debug|release]" >&2
        exit 2
        ;;
esac

if [[ "$CONFIGURATION" == "release" ]]; then
    SWIFT_BUILD_ARGS=(-c release)
    BINARY_PATH="$ROOT_DIR/.build/release/DeepOCRClip"
else
    SWIFT_BUILD_ARGS=()
    BINARY_PATH="$ROOT_DIR/.build/debug/DeepOCRClip"
fi

APP_DIR="$ROOT_DIR/dist/DeepOCRClip.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"

cd "$ROOT_DIR"

swift build "${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/DeepOCRClip"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/DeepOCRClip"

rm -rf "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable DeepOCRClip" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.luruiyang.deepocrclip" "$CONTENTS_DIR/Info.plist" >/dev/null

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

echo "$APP_DIR"
