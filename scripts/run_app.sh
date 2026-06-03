#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BIN=""
for candidate in \
    "/Applications/DeepOCRClip.app/Contents/MacOS/DeepOCRClip" \
    "$ROOT_DIR/dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip" \
    "$ROOT_DIR/.build/DeepOCRClip.app/Contents/MacOS/DeepOCRClip" \
    "$ROOT_DIR/DeepOCRClip.app/Contents/MacOS/DeepOCRClip"
do
    if [[ -x "$candidate" ]]; then
        APP_BIN="$candidate"
        break
    fi
done
STDOUT_LOG="/tmp/DeepOCRClip.stdout.log"

if [[ -z "$APP_BIN" ]]; then
    echo "DeepOCRClip executable not found. Run scripts/build_app.sh release first." >&2
    exit 1
fi

nohup "$APP_BIN" >"$STDOUT_LOG" 2>&1 &
echo "DeepOCRClip started with pid $!"
echo "stdout/stderr: $STDOUT_LOG"
echo "app log: $HOME/Library/Logs/DeepOCRClip.log"
