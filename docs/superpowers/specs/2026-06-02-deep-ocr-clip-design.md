# DeepOCRClip Design

## Goal

Build a lightweight native macOS menu bar app that replaces the practical workflow of CamScanner 2: trigger screenshot OCR with a hotkey, repair OCR errors with DeepSeek V4, copy the result automatically, and optionally paste it into the previously focused app. Add a result window modeled after the provided CamScanner reference, with the captured image on the left, recognized text on the right, and `Copy` plus `Translate` actions in the lower-right corner.

## First Version Scope

- Native macOS app, built with Swift and AppKit.
- Menu bar presence instead of a large dock-first app.
- Global hotkeys:
  - `Option+Shift+C`: screenshot, OCR, DeepSeek correction, copy.
  - `Option+Shift+V`: screenshot, OCR, DeepSeek correction, copy, then auto-paste.
  - `Option+Shift+T`: screenshot, OCR, DeepSeek correction, translate to Chinese, copy.
- Interactive screenshot region selection through macOS `screencapture`.
- Local OCR through Apple's Vision framework.
- DeepSeek V4 text post-processing for English OCR repair, word splitting, hyphen cleanup, and translation.
- Clipboard write after each successful recognition.
- Optional auto-paste by simulating `Cmd+V`, gated by macOS Accessibility permission.
- Result window:
  - Left pane: captured screenshot preview.
  - Right pane: editable recognized text.
  - Lower-right buttons: `复制` and `翻译`.
  - No `粘贴` button in the window; paste is a workflow mode and setting, not a result-window action.
- Settings window:
  - DeepSeek API key.
  - Model selector: `deepseek-v4-flash` by default, `deepseek-v4-pro` optional.
  - Enable or disable DeepSeek correction.
  - Enable or disable automatic paste after OCR.
  - Enable or disable result window after OCR.

## Architecture

The app uses focused services coordinated by `AppDelegate`.

- `CaptureService` runs `/usr/sbin/screencapture -i -r -x` and returns a temporary PNG path.
- `OCRService` uses `VNRecognizeTextRequest` on the captured image and returns ordered text lines.
- `DeepSeekClient` calls the DeepSeek OpenAI-compatible chat completion API for correction and translation.
- `ClipboardService` writes plain text to `NSPasteboard`.
- `PasteService` checks Accessibility permission and posts a synthetic `Cmd+V`.
- `HotKeyManager` registers global hotkeys through Carbon `RegisterEventHotKey`.
- `ResultWindowController` owns the two-pane result window and its copy/translate controls.
- `SettingsWindowController` owns the settings form and persists values in `UserDefaults`.
- `SettingsStore` provides typed access to persisted preferences.

The capture/OCR/LLM path runs as user-initiated async work. The result window is only activated after text has been copied, and in paste mode the paste event is sent before showing the result window to avoid stealing focus from the target app.

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
- Auto-paste: macOS Accessibility permission is required to post `Cmd+V`. The app prompts the user when this feature is used and permission is missing.
- Network: DeepSeek calls require internet access and a valid API key.

## Error Handling

- Cancelled screenshot: no clipboard change, status shows cancellation.
- Empty OCR result: result window shows an empty-state message and no DeepSeek request is sent.
- Missing API key: copy raw OCR text and show guidance to open settings.
- DeepSeek error: copy raw OCR text, keep the result window usable, and show the API error in the status line.
- Accessibility denied: keep copied text in clipboard and show a status message that auto-paste needs permission.

## Testing And Verification

- Build with Swift Package Manager.
- Package a `.app` bundle with a small shell script.
- Verify core compile with `swift build`.
- Manual smoke test:
  - Launch the app.
  - Configure DeepSeek API key.
  - Trigger `Option+Shift+C`, select a text region, confirm clipboard and result window.
  - Trigger `Option+Shift+V`, select a text region while another app is focused, confirm paste.
  - Click `翻译`, confirm Chinese text appears and can be copied.

## Non-Goals For First Version

- Custom screenshot overlay.
- OCR history database.
- Cloud image upload.
- Custom hotkey editor.
- Dock-style document browser.
- Full text editor with spellcheck UI.
