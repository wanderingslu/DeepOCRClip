import Foundation

struct RecognitionResult {
    let id: UUID
    let imageURL: URL
    let rawText: String
    var correctedText: String
    var translatedText: String?
    let createdAt: Date

    var visibleText: String {
        translatedText ?? correctedText
    }
}

enum AppError: LocalizedError {
    case captureCancelled
    case captureFailed(String)
    case screenCapturePermissionDenied
    case imageLoadFailed
    case noTextFound
    case missingAPIKey
    case deepSeekFailed(String)
    case accessibilityNotTrusted

    var errorDescription: String? {
        switch self {
        case .captureCancelled:
            return "已取消截图"
        case .captureFailed(let reason):
            return "截图失败：\(reason)"
        case .screenCapturePermissionDenied:
            return "需要授予屏幕录制权限后才能截图。授权后请重新启动 DeepOCRClip。"
        case .imageLoadFailed:
            return "无法读取截图图片"
        case .noTextFound:
            return "没有识别到文字"
        case .missingAPIKey:
            return "未配置 DeepSeek API Key，已使用本地 OCR 原文"
        case .deepSeekFailed(let reason):
            return "DeepSeek 请求失败：\(reason)"
        case .accessibilityNotTrusted:
            return "自动粘贴需要在系统设置中授予辅助功能权限"
        }
    }
}

struct AppStatus {
    let message: String
    let isError: Bool

    static func info(_ message: String) -> AppStatus {
        AppStatus(message: message, isError: false)
    }

    static func error(_ message: String) -> AppStatus {
        AppStatus(message: message, isError: true)
    }
}
