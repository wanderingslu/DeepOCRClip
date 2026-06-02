import Carbon
import Foundation

final class HotKeyManager {
    typealias Handler = @MainActor @Sendable (CaptureMode) -> Void

    private var handler: Handler?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private let signature = HotKeyManager.fourCharCode("DOCR")

    func register(handler: @escaping Handler) {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    manager.handleHotKey(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let modifiers = UInt32(optionKey | shiftKey)
        registerHotKey(keyCode: 8, modifiers: modifiers, id: 1)   // C
        registerHotKey(keyCode: 9, modifiers: modifiers, id: 2)   // V
        registerHotKey(keyCode: 17, modifiers: modifiers, id: 3)  // T
    }

    deinit {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
        }
    }

    private func handleHotKey(id: UInt32) {
        let mode: CaptureMode?
        switch id {
        case 1:
            mode = .copy
        case 2:
            mode = .paste
        case 3:
            mode = .translate
        default:
            mode = nil
        }

        guard let mode else { return }
        Task { @MainActor [handler] in
            handler?(mode)
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
