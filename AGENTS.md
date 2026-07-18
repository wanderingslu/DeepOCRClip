# DeepOCRClip Agent Guide

## Project Goal

DeepOCRClip is a small native macOS menu bar utility for this workflow:

1. Start an interactive region screenshot from a global shortcut.
2. Run local OCR.
3. Copy the local OCR result immediately.
4. Optionally ask DeepSeek to repair OCR artifacts.
5. Show an editable result window with copy and Chinese translation actions.

Preserve the app's lightweight, native, menu-bar-first character. Avoid adding
large runtimes or unrelated capture, annotation, history, or document-management
features unless the user explicitly requests them.

## Requirements and Invariants

- Minimum system: macOS 13.
- Language: Swift with AppKit; no Xcode project is required.
- Package: SwiftPM executable target in `Package.swift`.
- Bundle identifier: `com.luruiyang.deepocrclip`.
- Universal release architectures: `arm64` and `x86_64`.
- Status-bar symbol: `text.viewfinder`.
- API keys must come from app settings. Never hardcode or log them.
- Keep OCR useful without a DeepSeek API key.
- Keep local OCR and clipboard copy independent from network correction.

Do not change the bundle identifier or signing behavior casually. macOS Screen
Recording permission is tied to the app's code identity; identity drift can
cause repeated permission prompts or screenshots that contain only the desktop
background.

## Source Map

- `DeepOCRClipMain.swift`: app entry point and diagnostic CLI modes.
- `AppDelegate.swift`: menu bar UI and capture/OCR/correction workflow.
- `CaptureService.swift`: Screen Recording permission and `/usr/sbin/screencapture`.
- `OCRService.swift`: Vision OCR plus VisionKit fallback for tall vertical text.
- `DeepSeekClient.swift`: OCR repair and translation API requests.
- `TextCorrectionValidator.swift`: rejects translation, refusals, and unsafe
  model replacements of local OCR.
- `TextLayoutNormalizer.swift`: deterministic prose line-wrap normalization.
- `TextLanguageDetector.swift`: decides whether `翻中文` should call the API.
- `ResultWindowController.swift`: fixed-size editable OCR result window.
- `SettingsWindowController.swift`: API, model, and shortcut settings.
- `HotKeyRecorderControl.swift`: Chrome-style shortcut recorder.
- `scripts/build_app.sh`: two-architecture build, bundle assembly, and signing.
- `scripts/install_app.sh`: installs the built app into `/Applications`.
- `scripts/build_dmg.sh`: creates and verifies the DMG.

## Engineering Rules

- Read the existing implementation before changing behavior.
- Follow existing AppKit patterns and keep edits scoped.
- Preserve the local OCR result whenever DeepSeek fails or returns suspicious
  content.
- DeepSeek correction must repair OCR only. It must not translate, summarize,
  refuse, or rewrite the source.
- `翻中文` must leave Chinese-only text unchanged.
- The result text view must remain editable and support standard macOS editing
  commands, including selection, partial copy, undo, and `Command+W`.
- Keep the result window fixed-size, centered when shown, movable, closable, and
  minimizable. The screenshot preview must use aspect-fit.
- Do not add secrets, machine-specific absolute paths, logs, build products, app
  bundles, or DMGs to git.

## Build and Verification

For a quick source compile:

```bash
swift build
```

For the actual release artifact:

```bash
./scripts/build_app.sh release
```

Verify both architectures:

```bash
lipo -info dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip
```

Expected output must include both `x86_64` and `arm64`.

Run OCR directly against a user-provided regression image:

```bash
dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip \
  --ocr-image /absolute/path/to/sample.png
```

When OCR behavior changes, test at least:

- Simplified or Traditional Chinese.
- English continuous prose with wrapped lines.
- Mixed Chinese and English.
- A tall, narrow vertical Chinese sample.
- A failure or low-confidence case that must retain local OCR.

Before committing:

```bash
git diff --check
for file in scripts/*.sh; do bash -n "$file"; done
```

Installing writes to `/Applications`, terminates a running `DeepOCRClip`, and
opens Finder. Request user approval before running:

```bash
./scripts/install_app.sh
```

## Signing and Screen Recording

Run this once per development machine:

```bash
./scripts/create_signing_identity.sh
```

The build script prefers `DeepOCRClip Local Code Signing` and falls back to
ad-hoc signing when the identity is unavailable. Ad-hoc or changed identities
can make local TCC permission behavior unstable.

Useful checks:

```bash
codesign -d -r- dist/DeepOCRClip.app
dist/DeepOCRClip.app/Contents/MacOS/DeepOCRClip --self-test
```

The self-test prints `screenCaptureAccess=true` when permission is available.
Do not automate changes to System Settings or reset TCC unless the user asks.

## Release Discipline

- Source changes go to `main` only after relevant builds and OCR checks pass.
- Bump `CFBundleShortVersionString` and `CFBundleVersion` only for a new packaged
  release.
- Build the DMG from the exact committed source state.
- Verify the DMG with `hdiutil verify`.
- Treat every GitHub Release asset as public.
- Do not commit `dist/`; upload the verified DMG as a Release asset.
