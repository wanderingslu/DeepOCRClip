import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private let captureService = CaptureService()
    private let ocrService = OCRService()
    private let deepSeekClient = DeepSeekClient()
    private let hotKeyManager = HotKeyManager()

    private lazy var resultWindowController = ResultWindowController()
    private lazy var settingsWindowController = SettingsWindowController(settings: settings)

    private var statusItem: NSStatusItem?
    private let statusMenuItem = NSMenuItem(title: "准备就绪", action: nil, keyEquivalent: "")
    private var lastResult: RecognitionResult?
    private var isBusy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticsLogger.log("application launched")
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureResultWindowCallbacks()
        configureSettingsCallbacks()
        hotKeyManager.register { [weak self] action in
            self?.handleHotKey(action)
        }
        setStatus(.info("准备就绪"))
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            if let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "DeepOCRClip") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "OCR"
            }
            button.toolTip = "DeepOCRClip"
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "截图识别并复制    \(settings.captureHotKey.displayString)",
            action: #selector(captureAndCopy),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "显示上次结果    \(settings.showLastHotKey.displayString)",
            action: #selector(showLastResult),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem)
        statusMenuItem.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }

        statusItem?.menu = menu
    }

    private func configureResultWindowCallbacks() {
        resultWindowController.onTranslate = { [weak self] sourceText in
            self?.translateTextFromResultWindow(sourceText)
        }
    }

    private func configureSettingsCallbacks() {
        settingsWindowController.onSave = { [weak self] in
            guard let self else { return }
            self.hotKeyManager.reloadHotKeys(
                capture: self.settings.captureHotKey,
                showLastResult: self.settings.showLastHotKey
            )
            self.rebuildMenu()
            self.setStatus(.info("设置已保存"))
        }
    }

    private func setStatus(_ status: AppStatus) {
        DiagnosticsLogger.log("status: \(status.message)")
        statusMenuItem.title = status.message
        statusItem?.button?.toolTip = status.message
    }

    @objc private func captureAndCopy() {
        runCapture()
    }

    @objc private func showLastResult() {
        guard let lastResult else {
            setStatus(.error("还没有识别结果"))
            return
        }
        resultWindowController.show(result: lastResult, status: "上次识别结果")
    }

    @objc private func openSettings() {
        settingsWindowController.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func handleHotKey(_ action: HotKeyAction) {
        switch action {
        case .capture:
            runCapture()
        case .showLastResult:
            showLastResult()
        }
    }

    private func runCapture() {
        guard !isBusy else {
            setStatus(.info("正在处理上一张截图..."))
            return
        }

        isBusy = true
        setStatus(.info("选择截图区域..."))

        let apiKey = settings.apiKey
        let model = settings.model
        let correctionEnabled = settings.correctionEnabled
        let showResultWindow = settings.showResultWindow

        Task(priority: .userInitiated) {
            var capturedImageURL: URL?
            do {
                let imageURL = try await captureService.captureInteractiveRegion()
                capturedImageURL = imageURL
                DiagnosticsLogger.log("capture completed: \(imageURL.path)")
                await MainActor.run { self.setStatus(.info("正在识别文字...")) }

                let rawText = try await ocrService.recognizeText(from: imageURL)
                DiagnosticsLogger.log("ocr completed: \(rawText.count) chars")

                let result = RecognitionResult(
                    id: UUID(),
                    imageURL: imageURL,
                    rawText: rawText,
                    correctedText: rawText,
                    translatedText: nil,
                    createdAt: Date()
                )

                await MainActor.run {
                    self.showInitialResult(
                        result: result,
                        statusMessage: correctionEnabled && !apiKey.isEmpty ? "已复制本地 OCR，正在 DeepSeek 修正..." : "已复制识别结果",
                        showResultWindow: showResultWindow,
                        keepBusy: correctionEnabled && !apiKey.isEmpty
                    )
                }

                guard correctionEnabled else {
                    await MainActor.run { self.isBusy = false }
                    return
                }

                guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run {
                        self.isBusy = false
                        self.setStatus(.info("未配置 API Key，已复制本地 OCR 原文"))
                        self.resultWindowController.setStatus("未配置 API Key，已显示本地 OCR 原文", isError: false)
                    }
                    return
                }

                do {
                    let correctedText = try await deepSeekClient.correctOCRText(rawText, apiKey: apiKey, model: model)
                    DiagnosticsLogger.log("deepseek correction completed: \(correctedText.count) chars")
                    let correctedResult = RecognitionResult(
                        id: result.id,
                        imageURL: result.imageURL,
                        rawText: result.rawText,
                        correctedText: correctedText,
                        translatedText: result.translatedText,
                        createdAt: result.createdAt
                    )
                    await MainActor.run {
                        self.updateCorrectedResult(correctedResult, statusMessage: "DeepSeek 修正完成，已复制修正结果")
                    }
                } catch {
                    DiagnosticsLogger.log("deepseek correction failed: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isBusy = false
                        self.setStatus(.error("DeepSeek 修正失败，已保留本地 OCR"))
                        self.resultWindowController.setStatus("DeepSeek 修正失败，已保留本地 OCR", isError: true)
                    }
                }
            } catch {
                DiagnosticsLogger.log("capture workflow failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.isBusy = false
                    self.handleFailure(error, imageURL: capturedImageURL, showResultWindow: showResultWindow)
                }
            }
        }
    }

    private func showInitialResult(
        result: RecognitionResult,
        statusMessage: String,
        showResultWindow: Bool,
        keepBusy: Bool
    ) {
        lastResult = result
        ClipboardService.copy(result.visibleText)
        setStatus(.info(statusMessage))
        isBusy = keepBusy

        guard showResultWindow else { return }
        resultWindowController.show(result: result, status: statusMessage)
    }

    private func updateCorrectedResult(_ result: RecognitionResult, statusMessage: String) {
        lastResult = result
        ClipboardService.copy(result.visibleText)
        setStatus(.info(statusMessage))
        isBusy = false
        resultWindowController.update(result: result, status: statusMessage)
    }

    private func handleFailure(_ error: Error, imageURL: URL?, showResultWindow: Bool) {
        let message: String
        if let appError = error as? AppError {
            message = appError.localizedDescription
        } else {
            message = error.localizedDescription
        }
        setStatus(.error(message))

        guard let imageURL, showResultWindow else { return }
        let result = RecognitionResult(
            id: UUID(),
            imageURL: imageURL,
            rawText: "",
            correctedText: message,
            translatedText: nil,
            createdAt: Date()
        )
        lastResult = result
        resultWindowController.show(result: result, status: message)
        resultWindowController.setStatus(message, isError: true)
    }

    private func translateTextFromResultWindow(_ sourceText: String) {
        let apiKey = settings.apiKey
        let model = settings.model

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            resultWindowController.setTranslating(false)
            resultWindowController.setStatus("请先在设置中填写 DeepSeek API Key", isError: true)
            openSettings()
            return
        }

        Task(priority: .userInitiated) {
            do {
                let translation = try await deepSeekClient.translateToChinese(sourceText, apiKey: apiKey, model: model)
                DiagnosticsLogger.log("translation completed: \(translation.count) chars")
                await MainActor.run {
                    self.resultWindowController.setTranslating(false)
                    self.resultWindowController.applyTranslation(translation)
                    ClipboardService.copy(translation)
                    self.setStatus(.info("翻译完成，已复制中文"))
                }
            } catch {
                DiagnosticsLogger.log("translation failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.resultWindowController.setTranslating(false)
                    self.resultWindowController.setStatus(error.localizedDescription, isError: true)
                    self.setStatus(.error("翻译失败"))
                }
            }
        }
    }
}
