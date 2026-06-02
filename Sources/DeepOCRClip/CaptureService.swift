import CoreGraphics
import Foundation

final class CaptureService: @unchecked Sendable {
    func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func captureInteractiveRegion() async throws -> URL {
        guard hasScreenCaptureAccess() else {
            throw AppError.screenCapturePermissionDenied
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepOCRClip-\(UUID().uuidString)")
            .appendingPathExtension("png")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-r", "-x", outputURL.path]

            process.terminationHandler = { process in
                if process.terminationStatus == 0,
                   FileManager.default.fileExists(atPath: outputURL.path) {
                    continuation.resume(returning: outputURL)
                } else if process.terminationStatus == 1 {
                    continuation.resume(throwing: AppError.captureCancelled)
                } else {
                    continuation.resume(throwing: AppError.captureFailed("screencapture exited with \(process.terminationStatus)"))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AppError.captureFailed(error.localizedDescription))
            }
        }
    }
}
