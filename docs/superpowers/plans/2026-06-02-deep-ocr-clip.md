# DeepOCRClip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar OCR app that captures a screen region, recognizes text, repairs it with DeepSeek V4, copies it, and offers a CamScanner-style result window with copy and translation.

**Architecture:** The app is a Swift Package executable packaged into a `.app` bundle. AppKit owns the menu bar app, result window, and settings window; focused services handle capture, OCR, DeepSeek calls, clipboard, paste simulation, and global hotkeys.

**Tech Stack:** Swift 6, AppKit, Vision, Carbon hotkeys, ApplicationServices Accessibility APIs, URLSession, Swift Package Manager.

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `README.md`
- Create: `Resources/Info.plist`
- Create: `scripts/build_app.sh`

- [x] **Step 1: Create Swift Package metadata**

Define an executable target named `DeepOCRClip` for macOS 13 or newer.

- [x] **Step 2: Create app packaging script**

Build release binary with `swift build -c release`, copy it into `DeepOCRClip.app/Contents/MacOS`, copy `Info.plist`, and ad-hoc sign when `codesign` exists.

- [x] **Step 3: Verify scaffold**

Run: `swift package describe`

Expected: SwiftPM recognizes one executable target named `DeepOCRClip`.

### Task 2: Core Models And Settings

**Files:**
- Create: `Sources/DeepOCRClip/Models.swift`
- Create: `Sources/DeepOCRClip/SettingsStore.swift`

- [x] **Step 1: Define capture modes and recognition result model**

Add `RecognitionResult` and user-facing error types.

- [x] **Step 2: Implement settings persistence**

Use `UserDefaults` keys for API key, model, correction enabled, auto-paste, and result-window display.

### Task 3: Capture, OCR, DeepSeek, Clipboard, Paste Services

**Files:**
- Create: `Sources/DeepOCRClip/CaptureService.swift`
- Create: `Sources/DeepOCRClip/OCRService.swift`
- Create: `Sources/DeepOCRClip/DeepSeekClient.swift`
- Create: `Sources/DeepOCRClip/ClipboardService.swift`

- [x] **Step 1: Implement interactive screen capture**

Run `/usr/sbin/screencapture -i -r -x <temp.png>` and return the temp file URL.

- [x] **Step 2: Implement local OCR**

Use `VNRecognizeTextRequest` with accurate recognition and language correction, sorting text lines from top-to-bottom and left-to-right.

- [x] **Step 3: Implement DeepSeek correction and translation**

Post OpenAI-compatible chat completion requests to `https://api.deepseek.com/chat/completions` using model `deepseek-v4-flash` by default.

- [x] **Step 4: Implement clipboard service**

Copy plain text with `NSPasteboard`.

### Task 4: Menu Bar, Hotkeys, Result Window, Settings Window

**Files:**
- Create: `Sources/DeepOCRClip/HotKeyManager.swift`
- Create: `Sources/DeepOCRClip/ResultWindowController.swift`
- Create: `Sources/DeepOCRClip/SettingsWindowController.swift`
- Create: `Sources/DeepOCRClip/AppDelegate.swift`
- Create: `Sources/DeepOCRClip/main.swift`

- [x] **Step 1: Implement menu bar app shell**

Create an accessory app with an `OCR` status item and menu actions for capture/copy, capture/paste, capture/translate, last result, settings, and quit.

- [x] **Step 2: Implement global hotkeys**

Register customizable default hotkeys: `Option+Shift+C` for capture and `Option+Shift+L` for the last result window.

- [x] **Step 3: Implement result window**

Create a two-pane window: screenshot preview on the left, editable text on the right, `复制` and `翻译` buttons in the lower-right.

- [x] **Step 4: Implement settings window**

Create API key, model, correction, auto-paste, and result-window controls.

- [x] **Step 5: Wire workflow orchestration**

Capture image, OCR it, optionally correct with DeepSeek, copy result, and then show/update the result window. Translation runs from the result window button.

### Task 5: Build And Smoke Verification

**Files:**
- Modify as needed based on compiler feedback.

- [x] **Step 1: Build executable**

Run: `swift build`

Expected: build succeeds.

- [x] **Step 2: Package app**

Run: `scripts/build_app.sh`

Expected: `.build/DeepOCRClip.app` exists and contains the release binary.

- [x] **Step 3: Manual launch check**

Run the packaged app from Finder or terminal with `open .build/DeepOCRClip.app`.

Expected: menu bar item appears. Screen capture and Accessibility permissions may require user approval.

### Self-Review

- Spec coverage: all first-version scope items map to tasks above.
- Placeholder scan: no `TBD` or vague implementation placeholders remain.
- Type consistency: `RecognitionResult`, service names, and settings keys are consistent across tasks.
