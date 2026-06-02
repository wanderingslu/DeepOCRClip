# DeepOCRClip Design

## Goal

Build a lightweight native macOS menu bar app that replaces the practical workflow of CamScanner 2: trigger screenshot OCR with a hotkey, repair OCR errors with DeepSeek V4, copy the result automatically, and optionally paste it into the previously focused app. Add a result window modeled after the provided CamScanner reference, with the captured image on the left, recognized text on the right, and `Copy` plus `Translate` actions in the lower-right corner.

## First Version Scope

- Native macOS app, built with Swift and AppKit.
- Menu bar presence instead of a large dock-first app.
- Global hotkeys:
  - `Option+Shift+C` by default: screenshot, OCR, DeepSeek correction, copy.
  - `Option+Shift+L` by default: show the last result window.
  - Both hotkeys can be customized in Settings.
- Interactive screenshot region selection through macOS `screencapture`.
- Local OCR through Apple's Vision framework.
- DeepSeek V4 text post-processing for English OCR repair, word splitting, hyphen cleanup, and translation.
- Clipboard write after each successful recognition.
- Result window:
  - Left pane: captured screenshot preview.
  - Right pane: editable recognized text.
  - Lower-right buttons: `复制` and `翻译`.
  - No `粘贴` button in the window.
- Settings window:
  - DeepSeek API key.
  - Model selector: `deepseek-v4-flash` by default, `deepseek-v4-pro` optional.
  - Enable or disable DeepSeek correction.
  - Enable or disable result window after OCR.

## Architecture

The app uses focused services coordinated by `AppDelegate`.

- `CaptureService` runs `/usr/sbin/screencapture -i -r -x` and returns a temporary PNG path.
- `OCRService` uses `VNRecognizeTextRequest` on the captured image and returns ordered text lines.
- `DeepSeekClient` calls the DeepSeek OpenAI-compatible chat completion API for correction and translation.
- `ClipboardService` writes plain text to `NSPasteboard`.
- `HotKeyManager` registers global hotkeys through Carbon `RegisterEventHotKey`.
- `ResultWindowController` owns the two-pane result window and its copy/translate controls.
- `SettingsWindowController` owns the settings form and persists values in `UserDefaults`.
- `SettingsStore` provides typed access to persisted preferences.

The capture/OCR/LLM path runs as user-initiated async work. The result window is activated after text has been copied.

## DeepSeek Behavior

DeepSeek is not used for image OCR. Vision performs OCR locally so screenshots never need to be uploaded as images. DeepSeek receives recognized text only.

Correction prompt rules:

- Return only corrected text.
- Preserve the original language and meaning.
- Fix joined English words, broken hyphenation, spacing, and obvious OCR substitutions.
- Do not summarize, explain, or add content.

Translation prompt rules:

- Translate English text into natural Simplified Chinese.
- Preserve paragraph structure where useful.
- Return only the translation.

If no API key is configured, the app still performs local OCR and copies the raw Vision result. It shows a status message explaining that DeepSeek correction/translation needs an API key.

## Permissions

- Screen capture: macOS may request Screen Recording permission when `screencapture` is first used from the app.
- Network: DeepSeek calls require internet access and a valid API key.

## Error Handling

- Cancelled screenshot: no clipboard change, status shows cancellation.
- Empty OCR result: result window shows an empty-state message and no DeepSeek request is sent.
- Missing API key: copy raw OCR text and show guidance to open settings.
- DeepSeek error: copy raw OCR text, keep the result window usable, and show the API error in the status line.

## Testing And Verification

- Build with Swift Package Manager.
- Package a `.app` bundle with a small shell script.
- Verify core compile with `swift build`.
- Manual smoke test:
  - Launch the app.
  - Configure DeepSeek API key.
  - Trigger `Option+Shift+C`, select a text region, confirm clipboard and result window.
  - Click `翻译`, confirm Chinese text appears and can be copied.

## Non-Goals For First Version

- Custom screenshot overlay.
- OCR history database.
- Cloud image upload.
- Dock-style document browser.
- Full text editor with spellcheck UI.
