import AppKit

@main
struct DeepOCRClipMain {
    @MainActor
    static func main() {
        if let argumentIndex = CommandLine.arguments.firstIndex(of: "--ocr-image") {
            guard CommandLine.arguments.indices.contains(argumentIndex + 1) else {
                fputs("usage: DeepOCRClip --ocr-image <path>\n", stderr)
                exit(EXIT_FAILURE)
            }

            let imageURL = URL(fileURLWithPath: CommandLine.arguments[argumentIndex + 1])
            Task.detached {
                do {
                    print(try await OCRService().recognizeText(from: imageURL))
                    exit(EXIT_SUCCESS)
                } catch {
                    fputs("\(error.localizedDescription)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            }
            RunLoop.main.run()
            return
        }

        if CommandLine.arguments.contains("--self-test") {
            let captureService = CaptureService()
            print("screenCaptureAccess=\(captureService.hasScreenCaptureAccess())")
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
