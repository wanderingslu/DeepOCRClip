# Vertical OCR Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the failed custom vertical-glyph heuristic with a tested macOS VisionKit fallback.

**Architecture:** `VNRecognizeTextRequest` remains the normal path. Tall narrow images that produce no text fall back to `VisionKit.ImageAnalyzer` using an IOSurface-backed pixel buffer, while a diagnostic command makes the supplied image a repeatable end-to-end test.

**Tech Stack:** Swift 6, AppKit, Vision, VisionKit, CoreVideo, SwiftPM

---

### Task 1: Add a repeatable image OCR diagnostic

**Files:**
- Modify: `Sources/DeepOCRClip/DeepOCRClipMain.swift`

- [x] Add `--ocr-image <path>` handling that invokes `OCRService.recognizeText(from:)`, prints only the transcript, and exits nonzero on failure.
- [x] Build the current implementation and run it against the regression sample.
- [x] Confirm the current implementation fails with `没有识别到文字`.

### Task 2: Replace the vertical fallback

**Files:**
- Modify: `Sources/DeepOCRClip/OCRService.swift`

- [x] Import VisionKit and CoreVideo.
- [x] Keep the current Vision request as the primary path.
- [x] For tall narrow images with no primary result, create an IOSurface-backed BGRA pixel buffer and run `ImageAnalyzer.Configuration([.text])` with Simplified Chinese, Traditional Chinese, and English locales.
- [x] Return the trimmed `ImageAnalysis.transcript` when nonempty and log which fallback succeeded.
- [x] Delete `makePaddedImage`, `Bitmap`, `VerticalGlyphMask`, and horizontal glyph reconstruction.

### Task 3: Verify and install

**Files:**
- Verify: `Sources/DeepOCRClip/OCRService.swift`
- Verify: `Sources/DeepOCRClip/DeepOCRClipMain.swift`

- [x] Run `git diff --check`.
- [x] Compile all sources for `arm64-apple-macosx13.0` and `x86_64-apple-macosx13.0`.
- [x] Build the release app and run `--ocr-image` against the regression sample; expect `1989年西德电台采访首钢工人`.
- [x] Run the diagnostic on an ordinary horizontal OCR sample to confirm the primary path still works.
- [x] Install with `scripts/install_app.sh` and rerun the regression sample using `/Applications/DeepOCRClip.app/Contents/MacOS/DeepOCRClip`.
- [x] Commit the focused source and documentation changes.
