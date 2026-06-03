#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/DeepOCRClip.app"
DEST_DIR="/Applications/DeepOCRClip.app"

"$ROOT_DIR/scripts/build_app.sh" release

if pgrep -x DeepOCRClip >/dev/null 2>&1; then
    pkill -x DeepOCRClip || true
    sleep 1
fi

rm -rf "$DEST_DIR"
ditto "$APP_DIR" "$DEST_DIR"
xattr -cr "$DEST_DIR" 2>/dev/null || true
codesign --verify --deep --strict "$DEST_DIR"
open -R "$DEST_DIR"

echo "Installed: $DEST_DIR"
