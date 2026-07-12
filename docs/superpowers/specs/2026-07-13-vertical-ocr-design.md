# Vertical OCR Fallback Design

## Goal

Recognize upright, single-column vertical Chinese text on tall narrow screenshots while preserving DeepOCRClip's lightweight, offline, universal macOS distribution.

## Root Cause

Apple Vision's `VNRecognizeTextRequest` returns no observations for the supplied tall vertical sample. The existing fallback tries to infer glyphs with global luminance thresholds. On white text with black outlines over a mixed video background, the threshold mask merges outlines and background, so glyph detection returns no segments and OCR never receives a useful transformed image.

## Design

Keep Vision as the primary OCR engine for ordinary images. When the image is tall and narrow and primary recognition returns no text, run the system `VisionKit.ImageAnalyzer` text analysis and return its transcript. Feed it an IOSurface-backed `CVPixelBuffer` to avoid failures caused by non-IOSurface `CGImage` storage.

Remove the padded-image pass and all custom bitmap thresholding, glyph segmentation, and horizontal reconstruction code. They have no demonstrated success on the regression sample and add substantial untested complexity.

## Error Handling

If VisionKit is unsupported, pixel-buffer creation fails, or analysis returns an empty transcript, log the fallback failure and retain the existing `noTextFound` behavior. No network OCR or token-consuming model is used.

## Verification

Use `/var/folders/hg/qd2gdssn2qv_5ggkk18fdnzh0000gn/T/DeepOCRClip-6CBF5418-420B-4824-9A32-440BAC5896F1.png` as the regression input. The expected result is exactly `1989年西德电台采访首钢工人`. Build and verify both `arm64` and `x86_64`, then install the stable-signed app and rerun the sample through the installed binary's diagnostic OCR mode.

