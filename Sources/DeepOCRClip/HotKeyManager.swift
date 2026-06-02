import Carbon
import Foundation

final class HotKeyManager {
    typealias Handler = @MainActor @Sendable (HotKeyAction) -> Void

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

        reloadHotKeys(
            capture: SettingsStore.shared.captureHotKey,
            showLastResult: SettingsStore.shared.showLastHotKey
        )
    }

    func reloadHotKeys(capture: HotKeySetting, showLastResult: HotKeySetting) {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()

        registerHotKey(setting: capture, action: .capture)
        if showLastResult != capture {
            registerHotKey(setting: showLastResult, action: .showLastResult)
        }
    }

    deinit {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func registerHotKey(setting: HotKeySetting, action: HotKeyAction) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        let status = RegisterEventHotKey(
            setting.keyCode,
            setting.modifiers,
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
        guard let action = HotKeyAction(rawValue: id) else { return }
        Task { @MainActor [handler] in
            handler?(action)
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
