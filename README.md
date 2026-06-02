# DeepOCRClip

DeepOCRClip is a lightweight native macOS menu bar OCR app.

It captures a selected screen region, recognizes Simplified Chinese, Traditional Chinese, and English locally with Apple's Vision framework, optionally repairs OCR spacing and hyphenation with DeepSeek V4, and copies the result to the clipboard.

## Hotkeys

- `Option+Shift+C`: screenshot OCR, correct, copy.
- `Option+Shift+L`: show the last result window.

Both shortcuts can be changed in Settings. Translation is available from the `翻译` button in the result window.

## Build

```bash
swift build
./scripts/build_app.sh
```

The packaged app is written to `.build/DeepOCRClip.app`.

Until LaunchServices packaging is fixed, use the direct launcher:

```bash
./scripts/run_app.sh
```

Diagnostics are written to `~/Library/Logs/DeepOCRClip.log`.

## Notes

- Configure the DeepSeek API key from the app's settings menu.
- Without an API key, local OCR still works and copies raw OCR text.
- Screenshot capture may require macOS Screen Recording permission.
