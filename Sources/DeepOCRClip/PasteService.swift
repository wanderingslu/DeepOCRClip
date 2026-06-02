import ApplicationServices
import Foundation

@MainActor
final class PasteService {
    func pasteClipboardAfterDelay(_ delay: TimeInterval = 0.18) throws {
        guard requestAccessibilityIfNeeded() else {
            throw AppError.accessibilityNotTrusted
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.postCommandV()
        }
    }

    func requestAccessibilityIfNeeded() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
