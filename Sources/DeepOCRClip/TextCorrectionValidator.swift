import Foundation

enum TextCorrectionValidator {
    struct Verdict {
        let accepted: Bool
        let reason: String
    }

    static func validate(raw: String, corrected: String) -> Verdict {
        let rawText = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedText = corrected.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !correctedText.isEmpty else {
                return Verdict(accepted: false, reason: "修正结果为空")
            }

            if looksLikeAssistantRefusal(raw: rawText, corrected: correctedText) {
                return Verdict(accepted: false, reason: "修正结果是模型拒绝语或元回答")
            }

            if looksLikeShortLabelExpansion(raw: rawText, corrected: correctedText) {
                return Verdict(accepted: false, reason: "短文本从 \(meaningfulCharacterCount(in: rawText)) 字异常扩展到 \(meaningfulCharacterCount(in: correctedText)) 字")
            }

            let rawCJK = cjkCharacterCount(in: rawText)
        let correctedCJK = cjkCharacterCount(in: correctedText)

        if rawCJK >= 2 && correctedCJK == 0 {
            return Verdict(accepted: false, reason: "原文包含中文，但修正结果没有中文")
        }

        if rawCJK >= 4 {
            let minimumCJK = max(1, Int((Double(rawCJK) * 0.55).rounded(.down)))
            if correctedCJK < minimumCJK {
                return Verdict(accepted: false, reason: "中文字符数量从 \(rawCJK) 降到 \(correctedCJK)")
            }
        }

        let rawLatin = latinLetterCount(in: rawText)
        let correctedLatin = latinLetterCount(in: correctedText)

        if rawLatin >= 12 && correctedLatin < max(3, rawLatin / 4) && correctedCJK > rawCJK {
            return Verdict(accepted: false, reason: "英文内容疑似被翻译")
        }

        return Verdict(accepted: true, reason: "语言结构保真")
    }

    static func logSnippet(_ text: String, limit: Int = 180) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        if flattened.count <= limit {
            return flattened
        }
        return String(flattened.prefix(limit)) + "..."
    }

    private static func cjkCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            count + (isCJK(scalar) ? 1 : 0)
        }
    }

        private static func latinLetterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(0) { count, scalar in
            let value = scalar.value
            let isUppercaseLatin = value >= 65 && value <= 90
            let isLowercaseLatin = value >= 97 && value <= 122
            return count + ((isUppercaseLatin || isLowercaseLatin) ? 1 : 0)
        }
        }

        private static func looksLikeAssistantRefusal(raw: String, corrected: String) -> Bool {
            let rawNormalized = normalizedForPolicyCheck(raw)
            let correctedNormalized = normalizedForPolicyCheck(corrected)

            let metaRequests = [
                "请提供需要修复的ocr文本",
                "请提供ocr文本",
                "provide the ocr text",
                "provide ocr text"
            ]
            if metaRequests.contains(where: { correctedNormalized.contains($0) && !rawNormalized.contains($0) }) {
                return true
            }

            let refusalPhrases = [
                "无法处理这个请求",
                "不能处理这个请求",
                "无法协助",
                "不能协助",
                "无法提供",
                "不能提供",
                "i can't assist",
                "i cannot assist",
                "i'm unable",
                "i am unable",
                "sorry"
            ]
            let apologyPhrases = ["抱歉", "对不起", "sorry"]
            let hasRefusal = refusalPhrases.contains { correctedNormalized.contains($0) && !rawNormalized.contains($0) }
            let hasApology = apologyPhrases.contains { correctedNormalized.contains($0) && !rawNormalized.contains($0) }
            return hasRefusal && (hasApology || correctedNormalized.contains("请求") || correctedNormalized.contains("request"))
        }

        private static func looksLikeShortLabelExpansion(raw: String, corrected: String) -> Bool {
            let rawCount = meaningfulCharacterCount(in: raw)
            guard rawCount > 0 && rawCount <= 12 else { return false }

            let correctedCount = meaningfulCharacterCount(in: corrected)
            let allowedCount = max(rawCount + 8, rawCount * 2)
            return correctedCount > allowedCount
        }

        private static func meaningfulCharacterCount(in text: String) -> Int {
            text.unicodeScalars.reduce(0) { count, scalar in
                count + (CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar) ? 0 : 1)
            }
        }

        private static func normalizedForPolicyCheck(_ text: String) -> String {
            text
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\t", with: "")
        }

        private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2CEB0...0x2EBEF,
             0x30000...0x3134F:
            return true
        default:
            return false
        }
    }
}
