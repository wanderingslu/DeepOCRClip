#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BIN="$ROOT_DIR/DeepOCRClip.app/Contents/MacOS/DeepOCRClip"
STDOUT_LOG="/tmp/DeepOCRClip.stdout.log"

if [[ ! -x "$APP_BIN" ]]; then
    echo "DeepOCRClip executable not found: $APP_BIN" >&2
    exit 1
fi

nohup "$APP_BIN" >"$STDOUT_LOG" 2>&1 &
echo "DeepOCRClip started with pid $!"
echo "stdout/stderr: $STDOUT_LOG"
echo "app log: $HOME/Library/Logs/DeepOCRClip.log"
