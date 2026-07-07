import Foundation

enum TextLayoutNormalizer {
    static func normalizeContinuousProse(_ text: String) -> String {
        let normalizedNewlines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedNewlines.components(separatedBy: "\n")
        guard lines.count > 1 else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }

        var paragraphs: [String] = []
        var currentParagraph: [String] = []

        func flushParagraph() {
            guard !currentParagraph.isEmpty else { return }
            paragraphs.append(joinProseLines(currentParagraph))
            currentParagraph.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                continue
            }

            if isStructuralLine(line) {
                flushParagraph()
                paragraphs.append(line)
                continue
            }

            currentParagraph.append(line)
        }

        flushParagraph()
        return paragraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func joinProseLines(_ lines: [String]) -> String {
        var result = ""

        for line in lines {
            guard !result.isEmpty else {
                result = line
                continue
            }

            if result.hasSuffix("-") && shouldRemoveHyphenBeforeJoining(previous: result, next: line) {
                result.removeLast()
                result += line
            } else {
                result += " " + line
            }
        }

        return result
    }

    private static func shouldRemoveHyphenBeforeJoining(previous: String, next: String) -> Bool {
        guard let previousScalar = previous.dropLast().unicodeScalars.last,
              let nextScalar = next.unicodeScalars.first else {
            return false
        }
        return CharacterSet.letters.contains(previousScalar) && CharacterSet.letters.contains(nextScalar)
    }

    private static func isStructuralLine(_ line: String) -> Bool {
        if line.count <= 3 { return true }
        if line.contains("\t") { return true }
        if line.hasPrefix("http://") || line.hasPrefix("https://") { return true }
        if line.range(of: #"^\s*([-*•]|\d+[.)])\s+"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^([~/]|\w+:\\|[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"#, options: .regularExpression) != nil { return true }
        if looksLikeTableRow(line) { return true }
        return false
    }

    private static func looksLikeTableRow(_ line: String) -> Bool {
        let repeatedSpaces = line.range(of: #"\S\s{3,}\S"#, options: .regularExpression) != nil
        let separators = line.filter { $0 == "|" }.count
        return repeatedSpaces || separators >= 2
    }
}
