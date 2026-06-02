import AppKit

final class ResultWindowController: NSWindowController {
    var onTranslate: ((String) -> Void)?

    private let imageView = NSImageView()
    private let textView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "准备就绪")
    private let copyButton = NSButton(title: "复制", target: nil, action: nil)
    private let translateButton = NSButton(title: "翻译", target: nil, action: nil)

    private var currentResult: RecognitionResult?
    private var showingTranslation = false
    private var isTranslating = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "识别结果"
        window.minSize = NSSize(width: 860, height: 520)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = buildContentView()
        configureControls()
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
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? NSColor.systemRed : NSColor.secondaryLabelColor
    }

    func setTranslating(_ translating: Bool) {
        isTranslating = translating
        translateButton.isEnabled = !translating
        translateButton.title = translating ? "翻译中..." : (showingTranslation ? "原文" : "翻译")
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
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let leftPane = NSView()
        leftPane.translatesAutoresizingMaskIntoConstraints = false
        leftPane.wantsLayer = true
        leftPane.layer?.backgroundColor = NSColor(calibratedWhite: 0.955, alpha: 1).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter

        let imageScroll = NSScrollView()
        imageScroll.translatesAutoresizingMaskIntoConstraints = false
        imageScroll.drawsBackground = false
        imageScroll.hasVerticalScroller = true
        imageScroll.hasHorizontalScroller = true
        imageScroll.documentView = imageView

        let rightPane = NSView()
        rightPane.translatesAutoresizingMaskIntoConstraints = false
        rightPane.wantsLayer = true
        rightPane.layer?.backgroundColor = NSColor.white.cgColor

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        textView.textColor = NSColor.black
        textView.backgroundColor = NSColor.white
        textView.textContainerInset = NSSize(width: 26, height: 26)

        let textScroll = NSScrollView()
        textScroll.translatesAutoresizingMaskIntoConstraints = false
        textScroll.hasVerticalScroller = true
        textScroll.drawsBackground = true
        textScroll.backgroundColor = NSColor.white
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
        leftPane.addSubview(imageScroll)
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

            imageScroll.leadingAnchor.constraint(equalTo: leftPane.leadingAnchor, constant: 24),
            imageScroll.trailingAnchor.constraint(equalTo: leftPane.trailingAnchor, constant: -24),
            imageScroll.topAnchor.constraint(equalTo: leftPane.topAnchor, constant: 24),
            imageScroll.bottomAnchor.constraint(equalTo: leftPane.bottomAnchor, constant: -24),

            imageView.widthAnchor.constraint(greaterThanOrEqualTo: imageScroll.contentView.widthAnchor),
            imageView.heightAnchor.constraint(greaterThanOrEqualTo: imageScroll.contentView.heightAnchor),

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

    private func updateTranslateButton() {
        translateButton.title = showingTranslation ? "原文" : "翻译"
        translateButton.isEnabled = !isTranslating
    }

    @objc private func copyText() {
        ClipboardService.copy(textView.string)
        setStatus("已复制到剪贴板", isError: false)
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

        setTranslating(true)
        onTranslate?(sourceText)
    }

    private func setDisplayedText(_ text: String) {
        textView.string = text
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        if fullRange.length > 0 {
            textView.textStorage?.addAttributes([
                .foregroundColor: NSColor.black,
                .font: NSFont.systemFont(ofSize: 20, weight: .semibold)
            ], range: fullRange)
        }
        textView.typingAttributes = [
            .foregroundColor: NSColor.black,
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold)
        ]
    }
}
