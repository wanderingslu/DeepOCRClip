# Standard macOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package DeepOCRClip as a standard double-clickable macOS `.app` with stable bundle identity, icon resources, release build output, install helper, and updated docs.

**Architecture:** Keep SwiftPM as the source build system, then assemble a conventional app bundle under `dist/DeepOCRClip.app`. The bundle uses the existing `com.luruiyang.deepocrclip` identifier so macOS Screen Recording permissions stay tied to one stable identity.

**Tech Stack:** SwiftPM, AppKit, Vision, shell scripts, macOS `codesign`, `iconutil`.

---

### Task 1: Fix Release Build Compatibility

**Files:**
- Modify: `Sources/DeepOCRClip/ResultWindowController.swift`

- [x] **Step 1: Run release build**

Run: `scripts/build_app.sh release`

Expected before fix: Swift 6 reports `cannot access property 'keyMonitor' with a non-sendable type 'Any?' from nonisolated deinit`.

- [x] **Step 2: Remove app-lifetime monitor cleanup from `deinit`**

`ResultWindowController` is retained for the app lifetime by `AppDelegate`, so the local monitor does not need explicit removal at app termination.

- [x] **Step 3: Re-run release build**

Run: `scripts/build_app.sh release`

Expected: `.build/DeepOCRClip.app` is produced.

### Task 2: Standardize App Bundle Output

**Files:**
- Modify: `scripts/build_app.sh`
- Modify: `.gitignore`
- Modify: `Resources/Info.plist`
- Create: `scripts/generate_app_icon.swift`
- Create: `scripts/install_app.sh`

- [x] **Step 1: Build release app into `dist/DeepOCRClip.app`**

The script should default to release mode, copy the SwiftPM binary into `Contents/MacOS`, copy `Resources/Info.plist`, generate/copy `AppIcon.icns`, sign ad-hoc, and verify the signature.

- [x] **Step 2: Add install helper**

`scripts/install_app.sh` should build release, copy `dist/DeepOCRClip.app` into `/Applications/DeepOCRClip.app`, remove stale quarantine attributes, and reveal the app.

- [x] **Step 3: Update Info.plist**

Add `CFBundleIconFile`, `LSApplicationCategoryType`, and keep `LSUIElement=true` and `CFBundleIdentifier=com.luruiyang.deepocrclip`.

### Task 3: Verify And Publish

**Files:**
- Modify: `README.md`

- [x] **Step 1: Verify build artifacts**

Run: `scripts/build_app.sh release`, `codesign --verify --deep --strict dist/DeepOCRClip.app`, and `plutil -lint dist/DeepOCRClip.app/Contents/Info.plist`.

- [x] **Step 2: Update README**

Document GitHub repo, build, install, permissions, settings, and diagnostics.

- [x] **Step 3: Commit and push**

Run: `git add ...`, `git commit -m "feat: package standard macOS app"`, then `git push`.
