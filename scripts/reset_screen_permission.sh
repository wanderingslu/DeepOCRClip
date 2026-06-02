#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.luruiyang.deepocrclip"

pkill -x DeepOCRClip 2>/dev/null || true
tccutil reset ScreenCapture "$BUNDLE_ID"

echo "Reset ScreenCapture permission for $BUNDLE_ID"
echo "Restart DeepOCRClip, trigger screenshot once, then allow Screen Recording when macOS asks."
echo "Check with: DeepOCRClip.app/Contents/MacOS/DeepOCRClip --self-test"
