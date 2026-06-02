import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore

    private let apiKeyField = NSSecureTextField()
    private let modelPopup = NSPopUpButton()
    private let correctionCheckbox = NSButton(checkboxWithTitle: "使用 DeepSeek 修正 OCR 结果", target: nil, action: nil)
    private let autoPasteCheckbox = NSButton(checkboxWithTitle: "识别完成后自动粘贴", target: nil, action: nil)
    private let showResultCheckbox = NSButton(checkboxWithTitle: "识别完成后显示结果窗口", target: nil, action: nil)

    init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepOCRClip 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = buildContentView()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        loadSettings()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        apiKeyField.placeholderString = "sk-..."
        modelPopup.addItems(withTitles: SettingsStore.availableModels)

        let hotkeyLabel = NSTextField(labelWithString: "快捷键：⌥⇧C 复制，⌥⇧V 复制并粘贴，⌥⇧T 翻译")
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.font = .systemFont(ofSize: 12)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let grid = NSGridView(views: [
            [label("DeepSeek API Key"), apiKeyField],
            [label("模型"), modelPopup]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 330
        grid.rowSpacing = 14
        grid.columnSpacing = 12

        let stack = NSStackView(views: [
            grid,
            correctionCheckbox,
            autoPasteCheckbox,
            showResultCheckbox,
            hotkeyLabel,
            saveButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14

        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 28),
            saveButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])

        return root
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        return label
    }

    private func loadSettings() {
        apiKeyField.stringValue = settings.apiKey
        modelPopup.selectItem(withTitle: settings.model)
        correctionCheckbox.state = settings.correctionEnabled ? .on : .off
        autoPasteCheckbox.state = settings.autoPaste ? .on : .off
        showResultCheckbox.state = settings.showResultWindow ? .on : .off
    }

    @objc private func saveSettings() {
        settings.apiKey = apiKeyField.stringValue
        settings.model = modelPopup.titleOfSelectedItem ?? "deepseek-v4-flash"
        settings.correctionEnabled = correctionCheckbox.state == .on
        settings.autoPaste = autoPasteCheckbox.state == .on
        settings.showResultWindow = showResultCheckbox.state == .on
        window?.close()
    }
}
