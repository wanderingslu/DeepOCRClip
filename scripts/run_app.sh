#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR=""
for candidate in \
    "/Applications/DeepOCRClip.app" \
    "$ROOT_DIR/dist/DeepOCRClip.app" \
    "$ROOT_DIR/.build/DeepOCRClip.app" \
    "$ROOT_DIR/DeepOCRClip.app"
do
    if [[ -d "$candidate" && -x "$candidate/Contents/MacOS/DeepOCRClip" ]]; then
        APP_DIR="$candidate"
        break
    fi
done

if [[ -z "$APP_DIR" ]]; then
    echo "DeepOCRClip.app not found. Run scripts/build_app.sh release first." >&2
    exit 1
fi

open "$APP_DIR"
echo "DeepOCRClip opened: $APP_DIR"
echo "app log: $HOME/Library/Logs/DeepOCRClip.log"
