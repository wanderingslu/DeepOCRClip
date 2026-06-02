import AppKit
import Carbon

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore
    var onSave: (() -> Void)?

    private let apiKeyField = NSSecureTextField()
    private let modelPopup = NSPopUpButton()
    private let correctionCheckbox = NSButton(checkboxWithTitle: "使用 DeepSeek 修正 OCR 结果", target: nil, action: nil)
    private let showResultCheckbox = NSButton(checkboxWithTitle: "识别完成后显示结果窗口", target: nil, action: nil)
    private let captureCommandCheckbox = NSButton(checkboxWithTitle: "⌘", target: nil, action: nil)
    private let captureControlCheckbox = NSButton(checkboxWithTitle: "⌃", target: nil, action: nil)
    private let captureOptionCheckbox = NSButton(checkboxWithTitle: "⌥", target: nil, action: nil)
    private let captureShiftCheckbox = NSButton(checkboxWithTitle: "⇧", target: nil, action: nil)
    private let captureKeyPopup = NSPopUpButton()
    private let showLastCommandCheckbox = NSButton(checkboxWithTitle: "⌘", target: nil, action: nil)
    private let showLastControlCheckbox = NSButton(checkboxWithTitle: "⌃", target: nil, action: nil)
    private let showLastOptionCheckbox = NSButton(checkboxWithTitle: "⌥", target: nil, action: nil)
    private let showLastShiftCheckbox = NSButton(checkboxWithTitle: "⇧", target: nil, action: nil)
    private let showLastKeyPopup = NSPopUpButton()

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

        window?.setContentSize(NSSize(width: 600, height: 400))
        apiKeyField.placeholderString = "sk-..."
        modelPopup.addItems(withTitles: SettingsStore.availableModels)
        captureKeyPopup.addItems(withTitles: KeyCode.names)
        showLastKeyPopup.addItems(withTitles: KeyCode.names)

        let hotkeyLabel = NSTextField(labelWithString: "快捷键至少选择一个修饰键；翻译在结果窗口右下角点击。")
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.font = .systemFont(ofSize: 12)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let grid = NSGridView(views: [
            [label("DeepSeek API Key"), apiKeyField],
            [label("模型"), modelPopup],
            [label("截图识别并复制"), hotKeyEditor(
                command: captureCommandCheckbox,
                control: captureControlCheckbox,
                option: captureOptionCheckbox,
                shift: captureShiftCheckbox,
                keyPopup: captureKeyPopup
            )],
            [label("显示上次结果"), hotKeyEditor(
                command: showLastCommandCheckbox,
                control: showLastControlCheckbox,
                option: showLastOptionCheckbox,
                shift: showLastShiftCheckbox,
                keyPopup: showLastKeyPopup
            )]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 330
        grid.rowSpacing = 14
        grid.columnSpacing = 12

        let stack = NSStackView(views: [
            grid,
            correctionCheckbox,
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
        showResultCheckbox.state = settings.showResultWindow ? .on : .off
        loadHotKey(settings.captureHotKey, into: (
            captureCommandCheckbox,
            captureControlCheckbox,
            captureOptionCheckbox,
            captureShiftCheckbox,
            captureKeyPopup
        ))
        loadHotKey(settings.showLastHotKey, into: (
            showLastCommandCheckbox,
            showLastControlCheckbox,
            showLastOptionCheckbox,
            showLastShiftCheckbox,
            showLastKeyPopup
        ))
    }

    @objc private func saveSettings() {
        settings.apiKey = apiKeyField.stringValue
        settings.model = modelPopup.titleOfSelectedItem ?? "deepseek-v4-flash"
        settings.correctionEnabled = correctionCheckbox.state == .on
        settings.showResultWindow = showResultCheckbox.state == .on
        settings.captureHotKey = hotKeySetting(from: (
            captureCommandCheckbox,
            captureControlCheckbox,
            captureOptionCheckbox,
            captureShiftCheckbox,
            captureKeyPopup
        ), fallback: .defaultCapture)
        settings.showLastHotKey = hotKeySetting(from: (
            showLastCommandCheckbox,
            showLastControlCheckbox,
            showLastOptionCheckbox,
            showLastShiftCheckbox,
            showLastKeyPopup
        ), fallback: .defaultShowLastResult)
        onSave?()
        window?.close()
    }

    private func hotKeyEditor(
        command: NSButton,
        control: NSButton,
        option: NSButton,
        shift: NSButton,
        keyPopup: NSPopUpButton
    ) -> NSStackView {
        let stack = NSStackView(views: [command, control, option, shift, keyPopup])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        keyPopup.widthAnchor.constraint(equalToConstant: 76).isActive = true
        return stack
    }

    private func loadHotKey(
        _ setting: HotKeySetting,
        into controls: (NSButton, NSButton, NSButton, NSButton, NSPopUpButton)
    ) {
        controls.0.state = setting.modifiers & UInt32(cmdKey) != 0 ? .on : .off
        controls.1.state = setting.modifiers & UInt32(controlKey) != 0 ? .on : .off
        controls.2.state = setting.modifiers & UInt32(optionKey) != 0 ? .on : .off
        controls.3.state = setting.modifiers & UInt32(shiftKey) != 0 ? .on : .off
        controls.4.selectItem(withTitle: setting.keyName)
    }

    private func hotKeySetting(
        from controls: (NSButton, NSButton, NSButton, NSButton, NSPopUpButton),
        fallback: HotKeySetting
    ) -> HotKeySetting {
        let keyName = controls.4.titleOfSelectedItem ?? fallback.keyName
        let keyCode = KeyCode.lookup[keyName] ?? fallback.keyCode
        var modifiers: UInt32 = 0

        if controls.0.state == .on { modifiers |= UInt32(cmdKey) }
        if controls.1.state == .on { modifiers |= UInt32(controlKey) }
        if controls.2.state == .on { modifiers |= UInt32(optionKey) }
        if controls.3.state == .on { modifiers |= UInt32(shiftKey) }

        let setting = HotKeySetting(keyCode: keyCode, modifiers: modifiers, keyName: keyName)
        return setting.hasValidModifier ? setting : fallback
    }
}
