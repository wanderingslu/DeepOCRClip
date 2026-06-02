import Foundation

final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    private enum Key {
        static let apiKey = "deepseek.apiKey"
        static let model = "deepseek.model"
        static let correctionEnabled = "ocr.correctionEnabled"
        static let showResultWindow = "workflow.showResultWindow"
        static let captureHotKeyCode = "hotkey.capture.keyCode"
        static let captureHotKeyModifiers = "hotkey.capture.modifiers"
        static let captureHotKeyName = "hotkey.capture.keyName"
        static let showLastHotKeyCode = "hotkey.showLast.keyCode"
        static let showLastHotKeyModifiers = "hotkey.showLast.modifiers"
        static let showLastHotKeyName = "hotkey.showLast.keyName"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.model: "deepseek-v4-flash",
            Key.correctionEnabled: true,
            Key.showResultWindow: true,
            Key.captureHotKeyCode: Int(HotKeySetting.defaultCapture.keyCode),
            Key.captureHotKeyModifiers: Int(HotKeySetting.defaultCapture.modifiers),
            Key.captureHotKeyName: HotKeySetting.defaultCapture.keyName,
            Key.showLastHotKeyCode: Int(HotKeySetting.defaultShowLastResult.keyCode),
            Key.showLastHotKeyModifiers: Int(HotKeySetting.defaultShowLastResult.modifiers),
            Key.showLastHotKeyName: HotKeySetting.defaultShowLastResult.keyName
        ])
    }

    var apiKey: String {
        get { defaults.string(forKey: Key.apiKey) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.apiKey) }
    }

    var model: String {
        get {
            let saved = defaults.string(forKey: Key.model) ?? "deepseek-v4-flash"
            return Self.availableModels.contains(saved) ? saved : "deepseek-v4-flash"
        }
        set { defaults.set(newValue, forKey: Key.model) }
    }

    var correctionEnabled: Bool {
        get { defaults.bool(forKey: Key.correctionEnabled) }
        set { defaults.set(newValue, forKey: Key.correctionEnabled) }
    }

    var showResultWindow: Bool {
        get { defaults.bool(forKey: Key.showResultWindow) }
        set { defaults.set(newValue, forKey: Key.showResultWindow) }
    }

    var captureHotKey: HotKeySetting {
        get {
            hotKeySetting(
                codeKey: Key.captureHotKeyCode,
                modifiersKey: Key.captureHotKeyModifiers,
                nameKey: Key.captureHotKeyName,
                fallback: .defaultCapture
            )
        }
        set {
            setHotKeySetting(
                newValue,
                codeKey: Key.captureHotKeyCode,
                modifiersKey: Key.captureHotKeyModifiers,
                nameKey: Key.captureHotKeyName
            )
        }
    }

    var showLastHotKey: HotKeySetting {
        get {
            hotKeySetting(
                codeKey: Key.showLastHotKeyCode,
                modifiersKey: Key.showLastHotKeyModifiers,
                nameKey: Key.showLastHotKeyName,
                fallback: .defaultShowLastResult
            )
        }
        set {
            setHotKeySetting(
                newValue,
                codeKey: Key.showLastHotKeyCode,
                modifiersKey: Key.showLastHotKeyModifiers,
                nameKey: Key.showLastHotKeyName
            )
        }
    }

    static let availableModels = [
        "deepseek-v4-flash",
        "deepseek-v4-pro"
    ]

    private func hotKeySetting(codeKey: String, modifiersKey: String, nameKey: String, fallback: HotKeySetting) -> HotKeySetting {
        let keyName = defaults.string(forKey: nameKey) ?? fallback.keyName
        guard let keyCode = KeyCode.lookup[keyName],
              defaults.object(forKey: codeKey) != nil,
              defaults.object(forKey: modifiersKey) != nil else {
            return fallback
        }

        let modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        let setting = HotKeySetting(keyCode: keyCode, modifiers: modifiers, keyName: keyName)
        return setting.hasValidModifier ? setting : fallback
    }

    private func setHotKeySetting(_ setting: HotKeySetting, codeKey: String, modifiersKey: String, nameKey: String) {
        let safeSetting = setting.hasValidModifier ? setting : HotKeySetting(
            keyCode: setting.keyCode,
            modifiers: HotKeySetting.defaultCapture.modifiers,
            keyName: setting.keyName
        )
        defaults.set(Int(safeSetting.keyCode), forKey: codeKey)
        defaults.set(Int(safeSetting.modifiers), forKey: modifiersKey)
        defaults.set(safeSetting.keyName, forKey: nameKey)
    }
}
