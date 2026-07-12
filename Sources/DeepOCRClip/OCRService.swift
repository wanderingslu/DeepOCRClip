import CoreGraphics
import Foundation
import ImageIO
import Vision

final class OCRService: @unchecked Sendable {
    func recognizeText(from imageURL: URL) async throws -> String {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw AppError.imageLoadFailed
        }

        if let text = recognizeLinesIgnoringVisionError(in: cgImage, label: "primary"), !text.isEmpty {
            return text
        }

        if isTallNarrowImage(cgImage),
           let paddedImage = makePaddedImage(cgImage),
           let text = recognizeLinesIgnoringVisionError(in: paddedImage, label: "padded tall image"),
           !text.isEmpty {
            DiagnosticsLogger.log("ocr fallback succeeded: padded tall image")
            return text
        }

        if isTallNarrowImage(cgImage),
           let horizontalGlyphImage = makeHorizontalImageFromVerticalGlyphs(cgImage),
           let text = recognizeLinesIgnoringVisionError(in: horizontalGlyphImage, label: "vertical glyph rearrangement"),
           !text.isEmpty {
            DiagnosticsLogger.log("ocr fallback succeeded: vertical glyph rearrangement")
            return text.replacingOccurrences(of: "\n", with: "")
        }

        throw AppError.noTextFound
    }

    private func recognizeLinesIgnoringVisionError(in cgImage: CGImage, label: String) -> String? {
        do {
            return try recognizeLines(in: cgImage)
        } catch {
            DiagnosticsLogger.log("ocr pass failed (\(label)): \(error.localizedDescription)")
            return nil
        }
    }

    private func recognizeLines(in cgImage: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequest.currentRevision
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let preferredLanguages = ["zh-Hans", "zh-Hant", "en-US", "el-GR"]
        if let supportedLanguages = try? request.supportedRecognitionLanguages() {
            let supportedPreferredLanguages = preferredLanguages.filter { supportedLanguages.contains($0) }
            if !supportedPreferredLanguages.isEmpty {
                request.recognitionLanguages = supportedPreferredLanguages
            }
        } else {
            request.recognitionLanguages = preferredLanguages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = (request.results ?? []).sorted { left, right in
            let yDelta = abs(left.boundingBox.midY - right.boundingBox.midY)
            if yDelta > 0.018 {
                return left.boundingBox.midY > right.boundingBox.midY
            }
            return left.boundingBox.minX < right.boundingBox.minX
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func isTallNarrowImage(_ image: CGImage) -> Bool {
        image.height >= 180 && Double(image.height) / Double(max(image.width, 1)) >= 2.2
    }

    private func makePaddedImage(_ image: CGImage) -> CGImage? {
        let width = max(image.width, image.height)
        let height = image.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            return nil
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(
                x: (width - image.width) / 2,
                y: 0,
                width: image.width,
                height: image.height
            )
        )
        return context.makeImage()
    }

    private func makeHorizontalImageFromVerticalGlyphs(_ image: CGImage) -> CGImage? {
        guard let bitmap = Bitmap(image: image) else { return nil }
        let mask = VerticalGlyphMask(bitmap: bitmap)
        guard let glyphs = mask.detectGlyphs(), glyphs.count >= 2 else { return nil }

        DiagnosticsLogger.log("vertical glyph fallback detected \(glyphs.count) glyphs")
        return mask.makeHorizontalImage(from: glyphs)
    }
}

private struct Bitmap {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init?(image: CGImage) {
        let imageWidth = image.width
        let imageHeight = image.height
        var pixelBuffer = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let ok = pixelBuffer.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: imageWidth,
                height: imageHeight,
                bitsPerComponent: 8,
                bytesPerRow: imageWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }

            context.translateBy(x: 0, y: CGFloat(imageHeight))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            return true
        }

        guard ok else { return nil }
        width = imageWidth
        height = imageHeight
        pixels = pixelBuffer
    }

    func luminanceAt(x: Int, y: Int) -> Int {
        let offset = ((y * width) + x) * 4
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        return (red * 299 + green * 587 + blue * 114) / 1000
    }
}

private struct VerticalGlyphMask {
    struct Glyph {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int
    }

    private let bitmap: Bitmap
    private let useLightInk: Bool
    private let lightThreshold = 210
    private let darkThreshold = 55

    init(bitmap: Bitmap) {
        self.bitmap = bitmap

        var lightCount = 0
        var darkCount = 0
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let luminance = bitmap.luminanceAt(x: x, y: y)
                if luminance >= lightThreshold {
                    lightCount += 1
                }
                if luminance <= darkThreshold {
                    darkCount += 1
                }
            }
        }

        useLightInk = lightCount <= darkCount
    }

    func detectGlyphs() -> [Glyph]? {
        let rowThreshold = max(2, bitmap.width / 25)
        let maxGap = max(3, min(12, bitmap.height / 80))
        let rowCounts = (0..<bitmap.height).map { y in
            (0..<bitmap.width).reduce(0) { count, x in
                count + (isInkAt(x: x, y: y) ? 1 : 0)
            }
        }

        var ranges: [ClosedRange<Int>] = []
        var start: Int?
        var gap = 0

        for y in 0..<bitmap.height {
            if rowCounts[y] >= rowThreshold {
                if start == nil {
                    start = y
                }
                gap = 0
            } else if let currentStart = start {
                gap += 1
                if gap > maxGap {
                    let end = max(currentStart, y - gap)
                    ranges.append(currentStart...end)
                    start = nil
                    gap = 0
                }
            }
        }

        if let currentStart = start {
            ranges.append(currentStart...(bitmap.height - 1))
        }

        let glyphs = ranges.compactMap { range -> Glyph? in
            let height = range.upperBound - range.lowerBound + 1
            guard height >= 8 && height <= max(120, bitmap.width) else { return nil }

            var minX = bitmap.width
            var maxX = 0
            var inkCount = 0
            for y in range {
                for x in 0..<bitmap.width where isInkAt(x: x, y: y) {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    inkCount += 1
                }
            }

            guard inkCount >= 12 && minX <= maxX else { return nil }
            let padding = 4
            return Glyph(
                minX: max(0, minX - padding),
                maxX: min(bitmap.width - 1, maxX + padding),
                minY: max(0, range.lowerBound - padding),
                maxY: min(bitmap.height - 1, range.upperBound + padding)
            )
        }

        return glyphs.count >= 2 ? glyphs : nil
    }

    func makeHorizontalImage(from glyphs: [Glyph]) -> CGImage? {
        let cellSize = 96
        let margin = 10
        let width = cellSize * glyphs.count
        let height = cellSize
        var output = [UInt8](repeating: 255, count: width * height * 4)

        for pixel in stride(from: 0, to: output.count, by: 4) {
            output[pixel + 3] = 255
        }

        for (index, glyph) in glyphs.enumerated() {
            let glyphWidth = glyph.maxX - glyph.minX + 1
            let glyphHeight = glyph.maxY - glyph.minY + 1
            let scale = Double(cellSize - margin * 2) / Double(max(glyphWidth, glyphHeight))
            let scaledWidth = Double(glyphWidth) * scale
            let scaledHeight = Double(glyphHeight) * scale
            let offsetX = index * cellSize + Int((Double(cellSize) - scaledWidth) / 2)
            let offsetY = Int((Double(cellSize) - scaledHeight) / 2)
            let blockSize = max(1, Int(ceil(scale)))

            for sourceY in glyph.minY...glyph.maxY {
                for sourceX in glyph.minX...glyph.maxX where isInkAt(x: sourceX, y: sourceY) {
                    let destinationX = offsetX + Int(Double(sourceX - glyph.minX) * scale)
                    let destinationY = offsetY + Int(Double(sourceY - glyph.minY) * scale)
                    fillBlackBlock(
                        pixels: &output,
                        imageWidth: width,
                        imageHeight: height,
                        x: destinationX,
                        y: destinationY,
                        size: blockSize
                    )
                }
            }
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return output.withUnsafeMutableBytes { rawBuffer -> CGImage? in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return nil
            }
            return context.makeImage()
        }
    }

    private func isInkAt(x: Int, y: Int) -> Bool {
        let luminance = bitmap.luminanceAt(x: x, y: y)
        return useLightInk ? luminance >= lightThreshold : luminance <= darkThreshold
    }

    private func fillBlackBlock(pixels: inout [UInt8], imageWidth: Int, imageHeight: Int, x: Int, y: Int, size: Int) {
        for yy in y..<(y + size) where yy >= 0 && yy < imageHeight {
            for xx in x..<(x + size) where xx >= 0 && xx < imageWidth {
                let offset = ((yy * imageWidth) + xx) * 4
                pixels[offset] = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
                pixels[offset + 3] = 255
            }
        }
    }
}
