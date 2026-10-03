import Foundation

/// 通用 OpenAI 兼容 API 客户端
/// 支持任意 OpenAI 兼容端点：OpenAI 官方 / DeepSeek / 千问 / 百炼 / OpenRouter / OneAPI 等
/// 按 provider 自动适配扩展参数：联网搜索、思考档位
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
            case .httpError(let code, let body): return "请求失败（\(code)）：\(body.prefix(160))"
            case .decodeError(let msg): return "解析响应失败：\(msg)"
            case .missingAPIKey: return "请先在设置中填写 API Key"
            }
        }
    }

    // MARK: - Provider 识别

    /// 端点类型：决定扩展参数的注入方式
    enum ProviderKind: Sendable {
        case openai        // OpenAI 官方 / Azure / 遵循官方规范的中转
        case dashscope     // 千问 / 阿里云百炼
        case deepseek      // DeepSeek 官方
        case generic       // 其他 OpenAI 兼容（OpenRouter、OneAPI、NewAPI…）

        static func detect(baseURL: String) -> ProviderKind {
            let host = baseURL.lowercased()
            if host.contains("dashscope") || host.contains("aliyuncs")
                || host.contains("maas") || host.contains("qwencloud") {
                return .dashscope
            }
            if host.contains("api.deepseek.com") {
                return .deepseek
            }
            if host.contains("api.openai.com") || host.contains("openai.azure.com")
                || host.contains("azure.com") {
                return .openai
            }
            return .generic
        }
    }

    // MARK: - 流式对话

    struct ChatRequest: Sendable {
        let messages: [ChatMessage]
        let modelID: String
        let apiKey: String
        let baseURL: String
        let enableSearch: Bool
        let thinkingEffort: ThinkingEffort
    }

    func chatStream(_ req: ChatRequest) -> AsyncThrowingStream<StreamResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !req.apiKey.isEmpty else {
                        throw LLMError.missingAPIKey
                    }
                    let endpoint = Self.chatEndpoint(baseURL: req.baseURL)
                    guard let url = URL(string: endpoint) else {
                        throw LLMError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(req.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let kind = ProviderKind.detect(baseURL: req.baseURL)
                    let payload = Self.buildPayload(req: req, kind: kind)
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.decodeError("非 HTTP 响应")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var errBody = ""
                        for try await line in bytes.lines {
                            errBody += line
                            if errBody.count > 400 { break }
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
                        // 思考内容字段：DeepSeek/千问 reasoning_content，OpenAI o系列 reasoning
                        let thinking = (delta["reasoning_content"] as? String)
                            ?? (delta["reasoning"] as? String)

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

    // MARK: - 端点与 payload 构建

    /// 规范 baseURL：用户可能填根地址或已带 /v1，统一拼到 chat/completions
    static func chatEndpoint(baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/chat/completions") { return base }
        return "\(base)/chat/completions"
    }

    /// 按 provider 构建 payload：核心字段各家一致，扩展参数分层注入
    static func buildPayload(req: ChatRequest, kind: ProviderKind) -> [String: Any] {
        var payload: [String: Any] = [
            "model": req.modelID,
            "messages": req.messages.map { ["role": $0.role.rawValue, "content": $0.text] },
            "stream": true
        ]

        switch kind {
        case .dashscope:
            // 千问 / 百炼：enable_search + enable_thinking + thinking_budget
            if req.enableSearch {
                payload["enable_search"] = true
                payload["search_options"] = ["enable_source": true]
            }
            if req.thinkingEffort != .off {
                payload["enable_thinking"] = true
                if let budget = req.thinkingEffort.dashscopeThinkingBudget {
                    payload["thinking_budget"] = budget
                }
            }

        case .openai, .generic:
            // OpenAI 官方及规范中转：reasoning_effort 档位 + web_search 工具
            if let effort = req.thinkingEffort.openAIReasoningEffort {
                payload["reasoning_effort"] = effort
            }
            if req.enableSearch {
                payload["tools"] = [["type": "web_search"]]
                payload["tool_choice"] = "auto"
            }

        case .deepseek:
            // DeepSeek 官方：思考由模型决定（reasoner 自动思考），无档位参数；
            // 其 /chat/completions 不内置搜索，此处不注入避免 400。
            break
        }

        return payload
    }
}
