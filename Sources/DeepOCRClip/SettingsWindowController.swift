import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore
    var onSave: (() -> Void)?
    var onHotKeyChange: (() -> Void)?

    private let apiKeyField = PasteEnabledSecureTextField()
    private let modelPopup = NSPopUpButton()
    private let correctionCheckbox = NSButton(checkboxWithTitle: "使用 DeepSeek 修正 OCR 结果", target: nil, action: nil)
    private let showResultCheckbox = NSButton(checkboxWithTitle: "识别完成后显示结果窗口", target: nil, action: nil)
    private let captureRecorder = HotKeyRecorderControl(setting: .defaultCapture)
    private let showLastRecorder = HotKeyRecorderControl(setting: .defaultShowLastResult)
    private let shortcutMessageLabel = NSTextField(labelWithString: "点击铅笔图标后，直接键入新的快捷键。")

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
        configureShortcutRecorders()

        shortcutMessageLabel.textColor = .secondaryLabelColor
        shortcutMessageLabel.font = .systemFont(ofSize: 12)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let grid = NSGridView(views: [
            [label("DeepSeek API Key"), apiKeyField],
            [label("模型"), modelPopup],
            [label("截图识别并复制"), captureRecorder],
            [label("显示上次结果"), showLastRecorder]
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
            shortcutMessageLabel,
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
        captureRecorder.setting = settings.captureHotKey
        showLastRecorder.setting = settings.showLastHotKey
        setShortcutMessage("点击铅笔图标后，直接键入新的快捷键。", isError: false)
    }

    @objc private func saveSettings() {
        settings.apiKey = apiKeyField.stringValue
        settings.model = modelPopup.titleOfSelectedItem ?? "deepseek-v4-flash"
        settings.correctionEnabled = correctionCheckbox.state == .on
        settings.showResultWindow = showResultCheckbox.state == .on
        settings.captureHotKey = captureRecorder.setting
        settings.showLastHotKey = showLastRecorder.setting
        onSave?()
        window?.close()
    }

    private func configureShortcutRecorders() {
        captureRecorder.validator = { [weak self] setting in
            guard let self else { return nil }
            return setting == self.showLastRecorder.setting ? "两个功能不能使用同一个快捷键" : nil
        }
        showLastRecorder.validator = { [weak self] setting in
            guard let self else { return nil }
            return setting == self.captureRecorder.setting ? "两个功能不能使用同一个快捷键" : nil
        }

        captureRecorder.onChange = { [weak self] setting in
            guard let self else { return }
            self.settings.captureHotKey = setting
            self.onHotKeyChange?()
            self.setShortcutMessage("截图快捷键已更新为 \(setting.displayString)", isError: false)
        }
        showLastRecorder.onChange = { [weak self] setting in
            guard let self else { return }
            self.settings.showLastHotKey = setting
            self.onHotKeyChange?()
            self.setShortcutMessage("显示上次结果快捷键已更新为 \(setting.displayString)", isError: false)
        }

        captureRecorder.onValidationError = { [weak self] message in
            self?.setShortcutMessage(message, isError: true)
        }
        showLastRecorder.onValidationError = { [weak self] message in
            self?.setShortcutMessage(message, isError: true)
        }
    }

    private func setShortcutMessage(_ message: String, isError: Bool) {
        shortcutMessageLabel.stringValue = message
        shortcutMessageLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }
}

private final class PasteEnabledSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "v":
            currentEditor()?.paste(nil)
            return true
        case "c":
            currentEditor()?.copy(nil)
            return true
        case "x":
            currentEditor()?.cut(nil)
            return true
        case "a":
            currentEditor()?.selectAll(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
