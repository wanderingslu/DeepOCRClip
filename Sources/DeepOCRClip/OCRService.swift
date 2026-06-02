import AppKit
import Foundation
import Vision

final class OCRService: @unchecked Sendable {
    func recognizeText(from imageURL: URL) async throws -> String {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.deepOCRClipCGImage else {
            throw AppError.imageLoadFailed
        }

        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequest.currentRevision
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let preferredLanguages = ["zh-Hans", "zh-Hant", "en-US"]
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
        if text.isEmpty {
            throw AppError.noTextFound
        }
        return text
    }
}

private extension NSImage {
    var deepOCRClipCGImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
