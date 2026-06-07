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

APP_DIR="$ROOT_DIR/dist/DeepOCRClip.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_DIR="$ROOT_DIR/.build/deepocrclip-$CONFIGURATION"
DEFAULT_SIGNING_IDENTITY="DeepOCRClip Local Code Signing"
SIGNING_IDENTITY="${DEEP_OCR_CODESIGN_IDENTITY:-}"

cd "$ROOT_DIR"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

SWIFTC_ARGS=(
    -framework AppKit
    -framework Vision
    -framework Carbon
    -framework ApplicationServices
)

if [[ "$CONFIGURATION" == "release" ]]; then
    SWIFTC_ARGS=(-O "${SWIFTC_ARGS[@]}")
fi

for arch in x86_64 arm64; do
    echo "Building $CONFIGURATION slice: $arch"
    xcrun swiftc \
        -target "$arch-apple-macosx13.0" \
        "${SWIFTC_ARGS[@]}" \
        "$ROOT_DIR"/Sources/DeepOCRClip/*.swift \
        -o "$BUILD_DIR/DeepOCRClip-$arch"
done

lipo -create \
    "$BUILD_DIR/DeepOCRClip-x86_64" \
    "$BUILD_DIR/DeepOCRClip-arm64" \
    -output "$BUILD_DIR/DeepOCRClip"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/DeepOCRClip" "$MACOS_DIR/DeepOCRClip"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/DeepOCRClip"

cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable DeepOCRClip" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.luruiyang.deepocrclip" "$CONTENTS_DIR/Info.plist" >/dev/null

xattr -cr "$APP_DIR" 2>/dev/null || true
if [[ -z "$SIGNING_IDENTITY" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$DEFAULT_SIGNING_IDENTITY\""; then
    SIGNING_IDENTITY="$DEFAULT_SIGNING_IDENTITY"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="-"
fi

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
lipo "$MACOS_DIR/DeepOCRClip" -verify_arch x86_64 arm64

echo "$APP_DIR"
