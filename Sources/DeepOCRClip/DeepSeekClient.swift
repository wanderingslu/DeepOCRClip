import Foundation

final class DeepSeekClient: @unchecked Sendable {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func correctOCRText(_ text: String, apiKey: String, model: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.missingAPIKey
        }

        let system = """
        You repair OCR output from screenshots. Preserve the original language, paragraph order, and meaning. Fix joined English words, broken hyphenation, missing spaces, line-break artifacts, and obvious OCR substitutions. Return only the corrected text. Do not explain.
        """

        return try await sendChat(
            system: system,
            user: text,
            apiKey: apiKey,
            model: model,
            temperature: 0.1
        )
    }

    func translateToChinese(_ text: String, apiKey: String, model: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.missingAPIKey
        }

        let system = """
        Translate the user's English text into natural Simplified Chinese. Preserve paragraph structure where useful. Return only the Chinese translation. Do not explain.
        """

        return try await sendChat(
            system: system,
            user: text,
            apiKey: apiKey,
            model: model,
            temperature: 0.2
        )
    }

    private func sendChat(system: String, user: String, apiKey: String, model: String, temperature: Double) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            stream: false,
            temperature: temperature,
            thinking: .init(type: "disabled")
        )

        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.deepSeekFailed("no HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AppError.deepSeekFailed(message)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if content.isEmpty {
            throw AppError.deepSeekFailed("empty response")
        }
        return content
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let temperature: Double
    let thinking: Thinking
}

private struct Thinking: Encodable {
    let type: String
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
