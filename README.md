# DeepOCRClip

DeepOCRClip is a lightweight native macOS menu bar OCR app.

It captures a selected screen region, recognizes text locally with Apple's Vision framework, optionally repairs OCR spacing and hyphenation with DeepSeek V4, copies the result to the clipboard, and can auto-paste into the previously active app.

## Hotkeys

- `Option+Shift+C`: screenshot OCR, correct, copy.
- `Option+Shift+V`: screenshot OCR, correct, copy, auto-paste.
- `Option+Shift+T`: screenshot OCR, correct, translate to Simplified Chinese, copy.

## Build

```bash
swift build
./scripts/build_app.sh
```

The packaged app is written to `.build/DeepOCRClip.app`.

## Notes

- Configure the DeepSeek API key from the app's settings menu.
- Without an API key, local OCR still works and copies raw OCR text.
- Auto-paste requires macOS Accessibility permission.
- Screenshot capture may require macOS Screen Recording permission.
