# DeepOCRClip

DeepOCRClip is a lightweight native macOS menu bar OCR app. It captures a
selected screen region, recognizes text locally, optionally repairs OCR
artifacts with DeepSeek, and copies the result to the clipboard.

The app supports Simplified Chinese, Traditional Chinese, and English through
Apple Vision. Tall, narrow vertical text falls back to macOS Live Text through
VisionKit.

## Download

Download the packaged universal app from
[GitHub Releases](https://github.com/wanderingslu/DeepOCRClip/releases/latest).
The app contains both Apple Silicon (`arm64`) and Intel (`x86_64`) code.

The current package is locally signed rather than Apple-notarized. On first
launch, macOS may require opening it from Finder with Control-click > Open.
Screenshot capture also requires Screen Recording permission for
`DeepOCRClip`.

## Use

- Default screenshot OCR shortcut: `Option+Shift+C`
- Default show-last-result shortcut: `Option+Shift+L`
- Both shortcuts can be changed in Settings.
- The result window supports editing, selection, copy, undo, and `Command+W`.
- Use `翻中文` to translate foreign-language text into Simplified Chinese.

Configure a DeepSeek API key in Settings to enable OCR repair and translation.
Without an API key, local OCR and clipboard copy still work.

## Give This Project to Codex

This repository is public and contains the complete source and packaging
scripts:

```text
https://github.com/wanderingslu/DeepOCRClip
```

A useful prompt for Codex is:

```text
Clone and inspect https://github.com/wanderingslu/DeepOCRClip.
Read AGENTS.md before making changes. Implement my requested change,
run the relevant OCR regression checks, and verify both arm64 and x86_64
release builds. Do not change the bundle identifier or signing identity.
```

Codex can then clone the project:

```bash
git clone https://github.com/wanderingslu/DeepOCRClip.git
cd DeepOCRClip
```

## Build from Source

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Swift 6-compatible toolchain

Create the stable local signing identity once, then build the universal app:

```bash
./scripts/create_signing_identity.sh
./scripts/build_app.sh release
```

The result is written to `dist/DeepOCRClip.app`. To build and install it:

```bash
./scripts/install_app.sh
```

To create a distributable DMG:

```bash
./scripts/build_dmg.sh
```

The DMG is written to `dist/DeepOCRClip-<version>.dmg`.

## Verification

Run local OCR against a supplied image without starting the menu bar UI:

```bash
dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip \
  --ocr-image /absolute/path/to/sample.png
```

Verify the universal binary:

```bash
lipo -info dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip
```

Diagnostics from the normal app are written to:

```text
~/Library/Logs/DeepOCRClip.log
```

## Permission and Signing Notes

- Keep the bundle identifier `com.luruiyang.deepocrclip` stable. Changing it
  creates a new Screen Recording permission identity.
- Keep using the same `DeepOCRClip Local Code Signing` certificate on a
  developer machine to avoid repeated local permission prompts.
- `scripts/reset_screen_permission.sh` resets Screen Recording permission when
  a stale TCC entry must be cleared.
- Never commit a DeepSeek API key, `Secrets.plist`, an app bundle, DMG, or build
  directory.

See [AGENTS.md](AGENTS.md) for architecture and agent-specific development
guidance.
