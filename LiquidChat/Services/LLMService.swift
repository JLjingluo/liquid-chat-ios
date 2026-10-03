import Foundation

/// DeepSeek / 千问兼容的 OpenAI 格式 API 客户端
/// 默认指向 DeepSeek，可在设置里改成千问兼容端点
actor LLMService {
    static let shared = LLMService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    struct StreamResult: Sendable {
        let contentDelta: String?
        let thinkingDelta: String?
        let isDone: Bool
        let error: Error?
    }

    enum LLMError: LocalizedError {
        case invalidURL
        case httpError(Int, String)
        case decodeError(String)
        case missingAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的 API 地址"
            case .httpError(let code, let body): return "请求失败（\(code)）：\(body.prefix(120))"
            case .decodeError(let msg): return "解析响应失败：\(msg)"
            case .missingAPIKey: return "请先在设置中填写 API Key"
            }
        }
    }

    // MARK: - 流式对话

    func chatStream(
        messages: [ChatMessage],
        model: LLMModel,
        apiKey: String,
        baseURL: String
    ) -> AsyncThrowingStream<StreamResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else {
                        throw LLMError.missingAPIKey
                    }
                    let endpoint = "\(baseURL)/chat/completions"
                    guard let url = URL(string: endpoint) else {
                        throw LLMError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let payload: [String: Any] = [
                        "model": model.rawValue,
                        "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
                        "stream": true,
                        "temperature": 0.7
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.decodeError("非 HTTP 响应")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var errBody = ""
                        for try await line in bytes.lines {
                            errBody += line
                            if errBody.count > 300 { break }
                        }
                        throw LLMError.httpError(http.statusCode, errBody)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" {
                            continuation.yield(StreamResult(contentDelta: nil, thinkingDelta: nil, isDone: true, error: nil))
                            continuation.finish()
                            return
                        }

                        guard let data = jsonString.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any] else {
                            continue
                        }

                        let content = delta["content"] as? String
                        let thinking = delta["reasoning_content"] as? String

                        continuation.yield(StreamResult(
                            contentDelta: content,
                            thinkingDelta: thinking,
                            isDone: false,
                            error: nil
                        ))
                    }

                    continuation.yield(StreamResult(contentDelta: nil, thinkingDelta: nil, isDone: true, error: nil))
                    continuation.finish()
                } catch {
                    continuation.yield(StreamResult(contentDelta: nil, thinkingDelta: nil, isDone: true, error: error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
