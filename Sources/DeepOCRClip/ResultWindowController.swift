import AppKit

final class ResultWindowController: NSWindowController, NSTextViewDelegate {
    var onTranslate: ((String) -> Void)?
    var onResultChange: ((RecognitionResult) -> Void)?

    private let imageView = AspectFitImageView()
    private let textView = EditableResultTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 640))
    private let statusLabel = NSTextField(labelWithString: "准备就绪")
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let translateButton = NSButton(title: "翻中文", target: nil, action: nil)

    private var currentResult: RecognitionResult?
    private var showingTranslation = false
    private var isTranslating = false
    private var isSettingDisplayedText = false
    private var keyMonitor: Any?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "识别结果"
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor.white
        window.isMovable = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = buildContentView()
        configureControls()
        installCloseShortcut()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(result: RecognitionResult, status: String) {
        currentResult = result
        showingTranslation = result.translatedText != nil
        imageView.image = NSImage(contentsOf: result.imageURL)
        setDisplayedText(result.visibleText)
        setStatus(status, isError: false)
        updateTranslateButton()

        showWindow(nil)
        applyFixedWindowFrame(display: true)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(result: RecognitionResult, status: String, isError: Bool = false) {
        currentResult = result
        showingTranslation = result.translatedText != nil
        setDisplayedText(result.visibleText)
        setStatus(status, isError: isError)
        updateTranslateButton()
    }

    func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? NSColor.systemRed : NSColor.secondaryLabelColor
    }

    func setTranslating(_ translating: Bool) {
        isTranslating = translating
        translateButton.isEnabled = !translating
        translateButton.title = translating ? "翻译中..." : (showingTranslation ? "原文" : "翻中文")
    }

    func applyTranslation(_ translation: String) {
        guard var result = currentResult else { return }
        result.translatedText = translation
        currentResult = result
        showingTranslation = true
        setDisplayedText(translation)
        updateTranslateButton()
        setStatus("翻译完成，已显示中文译文", isError: false)
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.appearance = NSAppearance(named: .aqua)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let leftPane = NSView()
        leftPane.translatesAutoresizingMaskIntoConstraints = false
        leftPane.wantsLayer = true
        leftPane.layer?.backgroundColor = NSColor(calibratedWhite: 0.955, alpha: 1).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true

        let rightPane = NSView()
        rightPane.translatesAutoresizingMaskIntoConstraints = false
        rightPane.wantsLayer = true
        rightPane.layer?.backgroundColor = NSColor.white.cgColor

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = self
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        textView.textColor = NSColor.black
        textView.backgroundColor = NSColor.white
        textView.insertionPointColor = NSColor.black
        textView.appearance = NSAppearance(named: .aqua)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 26, height: 26)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        textView.selectedTextAttributes = [
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.systemBlue
        ]

        let textScroll = NSScrollView()
        textScroll.translatesAutoresizingMaskIntoConstraints = false
        textScroll.hasVerticalScroller = true
        textScroll.drawsBackground = true
        textScroll.backgroundColor = NSColor.white
        textScroll.contentView.backgroundColor = NSColor.white
        textScroll.documentView = textView

        let buttonBar = NSStackView()
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.orientation = .horizontal
        buttonBar.alignment = .centerY
        buttonBar.spacing = 12

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = NSFont.systemFont(ofSize: 13)

        buttonBar.addArrangedSubview(statusLabel)
        buttonBar.addArrangedSubview(NSView())
        buttonBar.addArrangedSubview(copyButton)
        buttonBar.addArrangedSubview(translateButton)

        root.addSubview(leftPane)
        root.addSubview(rightPane)
        leftPane.addSubview(imageView)
        rightPane.addSubview(textScroll)
        rightPane.addSubview(buttonBar)

        NSLayoutConstraint.activate([
            leftPane.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            leftPane.topAnchor.constraint(equalTo: root.topAnchor),
            leftPane.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            leftPane.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.5),

            rightPane.leadingAnchor.constraint(equalTo: leftPane.trailingAnchor),
            rightPane.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            rightPane.topAnchor.constraint(equalTo: root.topAnchor),
            rightPane.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: leftPane.leadingAnchor, constant: 24),
            imageView.trailingAnchor.constraint(equalTo: leftPane.trailingAnchor, constant: -24),
            imageView.topAnchor.constraint(equalTo: leftPane.topAnchor, constant: 24),
            imageView.bottomAnchor.constraint(equalTo: leftPane.bottomAnchor, constant: -24),

            textScroll.leadingAnchor.constraint(equalTo: rightPane.leadingAnchor),
            textScroll.trailingAnchor.constraint(equalTo: rightPane.trailingAnchor),
            textScroll.topAnchor.constraint(equalTo: rightPane.topAnchor),
            textScroll.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),

            buttonBar.leadingAnchor.constraint(equalTo: rightPane.leadingAnchor, constant: 26),
            buttonBar.trailingAnchor.constraint(equalTo: rightPane.trailingAnchor, constant: -26),
            buttonBar.bottomAnchor.constraint(equalTo: rightPane.bottomAnchor, constant: -24),
            buttonBar.heightAnchor.constraint(equalToConstant: 48),

            copyButton.widthAnchor.constraint(equalToConstant: 112),
            copyButton.heightAnchor.constraint(equalToConstant: 38),
            translateButton.widthAnchor.constraint(equalToConstant: 112),
            translateButton.heightAnchor.constraint(equalToConstant: 38)
        ])

        return root
    }

    private func applyFixedWindowFrame(display: Bool) {
        guard let window else { return }

        let visibleFrame = (window.screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let contentSize = fixedContentSize(for: visibleFrame)
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let origin = NSPoint(
            x: visibleFrame.midX - frameSize.width / 2,
            y: visibleFrame.midY - frameSize.height / 2
        )

        let frame = NSRect(origin: origin, size: frameSize)
        DiagnosticsLogger.log(
            "result window frame set: visible=\(Int(visibleFrame.width))x\(Int(visibleFrame.height)), content=\(Int(contentSize.width))x\(Int(contentSize.height)), frame=\(Int(frame.width))x\(Int(frame.height))"
        )
        window.setFrame(frame, display: display)
    }

    private func fixedContentSize(for visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: clamped(visibleFrame.width * 0.5, minimum: 760, maximum: 1040),
            height: clamped(visibleFrame.height * 0.5, minimum: 500, maximum: 680)
        )
    }

    private func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value.rounded(.down), minimum), maximum)
    }

    private func configureControls() {
        copyButton.target = self
        copyButton.action = #selector(copyText)
        copyButton.bezelStyle = .rounded
        copyButton.contentTintColor = NSColor.white
        copyButton.wantsLayer = true
        copyButton.layer?.backgroundColor = NSColor.systemTeal.cgColor
        copyButton.layer?.cornerRadius = 7

        translateButton.target = self
        translateButton.action = #selector(translateOrToggle)
        translateButton.bezelStyle = .rounded
        translateButton.contentTintColor = NSColor.controlTextColor
        translateButton.wantsLayer = true
        translateButton.layer?.cornerRadius = 7
    }

    private func installCloseShortcut() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.window?.isKeyWindow == true else {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "w" {
                self.window?.performClose(nil)
                return nil
            }

            return event
        }
    }

    private func updateTranslateButton() {
        translateButton.title = showingTranslation ? "原文" : "翻中文"
        translateButton.isEnabled = !isTranslating
    }

    @objc private func copyText() {
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            ClipboardService.copy(selectedText)
            setStatus("已复制选中文本", isError: false)
        } else {
            ClipboardService.copy(textView.string)
            setStatus("已复制到剪贴板", isError: false)
        }
    }

    @objc private func translateOrToggle() {
        guard !isTranslating else { return }

        if showingTranslation, let currentResult {
            showingTranslation = false
            setDisplayedText(currentResult.correctedText)
            updateTranslateButton()
            setStatus("已切回识别原文", isError: false)
            return
        }

        let sourceText = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            setStatus("没有可翻译的文本", isError: true)
            return
        }

        guard TextLanguageDetector.containsForeignLetters(in: sourceText) else {
            setStatus("内容已是中文，无需翻译", isError: false)
            return
        }

        setTranslating(true)
        onTranslate?(sourceText)
    }

    private func setDisplayedText(_ text: String) {
        isSettingDisplayedText = true
        defer { isSettingDisplayedText = false }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.black,
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .backgroundColor: NSColor.white
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        textView.typingAttributes = [
            .foregroundColor: NSColor.black,
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .backgroundColor: NSColor.white
        ]
        textView.textColor = NSColor.black
        textView.backgroundColor = NSColor.white
        textView.needsDisplay = true
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        textView.enclosingScrollView?.documentView?.setFrameSize(
            NSSize(width: textView.enclosingScrollView?.contentSize.width ?? 560, height: max(usedHeight + 80, 640))
        )
        textView.undoManager?.removeAllActions()
    }

    func textDidChange(_ notification: Notification) {
        guard !isSettingDisplayedText,
              var result = currentResult else {
            return
        }

        if showingTranslation {
            result.translatedText = textView.string
        } else {
            result.correctedText = textView.string
        }
        currentResult = result
        onResultChange?(result)
    }
}

private final class EditableResultTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch (flags, key) {
        case (.command, "z"):
            undoManager?.undo()
            return true
        case ([.command, .shift], "z"):
            undoManager?.redo()
            return true
        case (.command, "x"):
            copySelectedText()
            insertText("", replacementRange: selectedRange())
            return true
        case (.command, "c"):
            copySelectedText()
            return true
        case (.command, "v"):
            if let pastedText = NSPasteboard.general.string(forType: .string) {
                insertText(pastedText, replacementRange: selectedRange())
            }
            return true
        case (.command, "a"):
            selectAll(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    private func copySelectedText() {
        let range = selectedRange()
        guard range.length > 0 else { return }
        ClipboardService.copy((string as NSString).substring(with: range))
    }
}

private final class AspectFitImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image else { return }

        let targetRect = aspectFitRect(imageSize: image.size, bounds: bounds)
        image.draw(
            in: targetRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func aspectFitRect(imageSize: NSSize, bounds: NSRect) -> NSRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return .zero
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        ).integral
    }
}
