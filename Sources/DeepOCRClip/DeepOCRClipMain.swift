import AppKit

@main
struct DeepOCRClipMain {
    @MainActor
    static func main() {
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
