import AppKit
import Carbon

final class HotKeyRecorderControl: NSView {
    var setting: HotKeySetting {
        didSet {
            if oldValue != setting {
                updateDisplay()
            }
        }
    }

    var validator: ((HotKeySetting) -> String?)?
    var onChange: ((HotKeySetting) -> Void)?
    var onValidationError: ((String) -> Void)?

    private let displayContainer = NSView()
    private let displayLabel = NSTextField(labelWithString: "")
    private let editButton = NSButton()
    private var isRecording = false

    init(setting: HotKeySetting = .defaultCapture) {
        self.setting = setting
        super.init(frame: .zero)
        buildView()
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            updateDisplay()
        }
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handleShortcutEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        handleShortcutEvent(event)
        return true
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false

        displayContainer.translatesAutoresizingMaskIntoConstraints = false
        displayContainer.wantsLayer = true
        displayContainer.layer?.cornerRadius = 6
        displayContainer.layer?.borderWidth = 1

        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        displayLabel.alignment = .center
        displayLabel.lineBreakMode = .byTruncatingMiddle

        displayContainer.addSubview(displayLabel)

        if let image = NSImage(systemSymbolName: "pencil", accessibilityDescription: "编辑快捷键") {
            editButton.image = image
            editButton.imagePosition = .imageOnly
        } else {
            editButton.title = "编辑"
        }
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.bezelStyle = .rounded
        editButton.target = self
        editButton.action = #selector(editShortcut)
        editButton.toolTip = "编辑快捷键"

        let stack = NSStackView(views: [displayContainer, editButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            displayContainer.widthAnchor.constraint(equalToConstant: 190),
            displayContainer.heightAnchor.constraint(equalToConstant: 30),
            displayLabel.leadingAnchor.constraint(equalTo: displayContainer.leadingAnchor, constant: 10),
            displayLabel.trailingAnchor.constraint(equalTo: displayContainer.trailingAnchor, constant: -10),
            displayLabel.centerYAnchor.constraint(equalTo: displayContainer.centerYAnchor),

            editButton.widthAnchor.constraint(equalToConstant: 32),
            editButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func editShortcut() {
        beginRecording()
    }

    private func beginRecording() {
        isRecording = true
        updateDisplay()
        window?.makeFirstResponder(self)
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            updateDisplay()
            return
        }

        guard let candidate = hotKeySetting(from: event) else {
            onValidationError?("快捷键需要是“修饰键 + 字母/数字”，例如 ⌘1 或 ⌥⇧C")
            return
        }

        if let error = validator?(candidate) {
            onValidationError?(error)
            return
        }

        setting = candidate
        isRecording = false
        updateDisplay()
        onChange?(candidate)
    }

    private func hotKeySetting(from event: NSEvent) -> HotKeySetting? {
        let keyCode = UInt32(event.keyCode)
        guard let keyName = KeyCode.name(for: keyCode) else {
            return nil
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }

        let candidate = HotKeySetting(keyCode: keyCode, modifiers: modifiers, keyName: keyName)
        return candidate.hasValidModifier ? candidate : nil
    }

    private func updateDisplay() {
        displayLabel.stringValue = isRecording ? "键入快捷键" : setting.displayString
        displayLabel.textColor = isRecording ? .controlAccentColor : .labelColor

        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        let backgroundColor: NSColor = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.08) : .controlBackgroundColor
        displayContainer.layer?.borderColor = borderColor.cgColor
        displayContainer.layer?.backgroundColor = backgroundColor.cgColor
    }
}
