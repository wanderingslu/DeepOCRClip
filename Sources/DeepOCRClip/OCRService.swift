import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision
import VisionKit

final class OCRService: @unchecked Sendable {
    private let preferredLanguages = ["zh-Hans", "zh-Hant", "en-US", "el-GR"]

    func recognizeText(from imageURL: URL) async throws -> String {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw AppError.imageLoadFailed
        }

        if let text = recognizeLinesIgnoringVisionError(in: cgImage), !text.isEmpty {
            return text
        }

        if isTallNarrowImage(cgImage),
           let text = await recognizeVerticalTextWithVisionKit(in: cgImage),
           !text.isEmpty {
            DiagnosticsLogger.log("ocr fallback succeeded: VisionKit vertical text")
            return text
        }

        throw AppError.noTextFound
    }

    private func recognizeLinesIgnoringVisionError(in cgImage: CGImage) -> String? {
        do {
            return try recognizeLines(in: cgImage)
        } catch {
            DiagnosticsLogger.log("ocr primary pass failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func recognizeLines(in cgImage: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequest.currentRevision
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        if let supportedLanguages = try? request.supportedRecognitionLanguages() {
            let supportedPreferredLanguages = preferredLanguages.filter(supportedLanguages.contains)
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

    private func recognizeVerticalTextWithVisionKit(in cgImage: CGImage) async -> String? {
        guard ImageAnalyzer.isSupported,
              let pixelBuffer = makeIOSurfacePixelBuffer(from: cgImage) else {
            DiagnosticsLogger.log("ocr VisionKit fallback unavailable")
            return nil
        }

        let supportedLanguages = Set(ImageAnalyzer.supportedTextRecognitionLanguages)
        let locales = preferredLanguages.filter(supportedLanguages.contains)
        var configuration = ImageAnalyzer.Configuration([.text])
        if !locales.isEmpty {
            configuration.locales = locales
        }

        do {
            let analysis = try await ImageAnalyzer().analyze(
                pixelBuffer,
                orientation: .up,
                configuration: configuration
            )
            let text = analysis.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            DiagnosticsLogger.log("ocr VisionKit fallback failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func isTallNarrowImage(_ image: CGImage) -> Bool {
        image.height >= 180 && Double(image.height) / Double(max(image.width, 1)) >= 2.2
    }

    private func makeIOSurfacePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            DiagnosticsLogger.log("ocr pixel buffer creation failed: \(status)")
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
              ) else {
            DiagnosticsLogger.log("ocr pixel buffer drawing context creation failed")
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixelBuffer
    }
}
