import Foundation

final class SettingsStore: @unchecked Sendable {
    static let shared = SettingsStore()

    private enum Key {
        static let apiKey = "deepseek.apiKey"
        static let model = "deepseek.model"
        static let correctionEnabled = "ocr.correctionEnabled"
        static let autoPaste = "workflow.autoPaste"
        static let showResultWindow = "workflow.showResultWindow"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.model: "deepseek-v4-flash",
            Key.correctionEnabled: true,
            Key.autoPaste: false,
            Key.showResultWindow: true
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

    var autoPaste: Bool {
        get { defaults.bool(forKey: Key.autoPaste) }
        set { defaults.set(newValue, forKey: Key.autoPaste) }
    }

    var showResultWindow: Bool {
        get { defaults.bool(forKey: Key.showResultWindow) }
        set { defaults.set(newValue, forKey: Key.showResultWindow) }
    }

    static let availableModels = [
        "deepseek-v4-flash",
        "deepseek-v4-pro"
    ]
}
