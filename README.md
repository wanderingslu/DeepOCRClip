# DeepOCRClip

DeepOCRClip is a lightweight native macOS menu bar OCR app.

It captures a selected screen region, recognizes Simplified Chinese, Traditional Chinese, and English locally with Apple's Vision framework, optionally repairs OCR spacing and hyphenation with DeepSeek V4, and copies the result to the clipboard.

## Hotkeys

- `Option+Shift+C`: screenshot OCR, correct, copy.
- `Option+Shift+L`: show the last result window.

Both shortcuts can be changed in Settings. Translation is available from the `翻译` button in the result window.

## Build

```bash
./scripts/create_signing_identity.sh
./scripts/build_app.sh release
```

The packaged universal app (`x86_64` + `arm64`) is written to `dist/DeepOCRClip.app`.

## Install

```bash
./scripts/install_app.sh
```

This builds a release app and installs it to `/Applications/DeepOCRClip.app`.
You can then start it by double-clicking the app, or keep using the helper launcher:

```bash
./scripts/run_app.sh
```

Diagnostics are written to `~/Library/Logs/DeepOCRClip.log`.

## DMG

```bash
./scripts/build_dmg.sh
```

The DMG contains the universal app and is written to `dist/DeepOCRClip-<version>.dmg`.

## Notes

- Configure the DeepSeek API key from the app's settings menu.
- Without an API key, local OCR still works and copies raw OCR text.
- Screenshot capture requires macOS Screen Recording permission for `DeepOCRClip`.
- For stable macOS permission behavior across rebuilds, run `./scripts/create_signing_identity.sh` once before packaging.
