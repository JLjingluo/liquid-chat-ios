import Foundation

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

// MARK: - 流式结果

struct StreamResult: Sendable {
    let contentDelta: String?
    let thinkingDelta: String?
    let isDone: Bool
    let error: Error?
}

// MARK: - 错误

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

// MARK: - 请求参数

struct ChatRequest: Sendable {
    var messages: [ChatMessage]
    var modelID: String
    var apiKey: String
    var baseURL: String
    var enableSearch: Bool
    var thinkingEffort: ThinkingEffort
    /// 采样温度。nil 表示不发送该字段（由服务端决定）
    var temperature: Double? = nil
    /// 单次回复最大 token 数。nil 表示不发送该字段
    var maxTokens: Int? = nil
}

// MARK: - LLMClient

/// OpenAI-compatible 流式客户端。
///
/// 为什么不用 ChatGPTSwift 自带的 `ChatGPTAPI`：它的 baseURL 是
/// `private let urlString = "https://api.openai.com/v1"` 硬编码，且构造器
/// 只接受 apiKey，无法接入 DeepSeek / 千问等兼容端点，因此此处自行实现。
///
/// 流式解析与容错策略参考 SerenadeX/Soryn（MIT）的 OpenAIClient / CustomLLMClient：
/// - 端点规范化（容忍用户填根地址、/v1 或完整路径）
/// - 非流式回退（中转站忽略 stream:true 时直接返回完整 JSON）
/// - 重定向时保留 Authorization 头
/// - continuation.onTermination 实现真正的取消
protocol LLMClient: Sendable {
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamResult, Error>
}

struct OpenAICompatibleClient: LLMClient {

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamResult, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(request, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    // 用户主动停止：不视为错误
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // 消费方取消（停止生成）时中止底层请求
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: 实际请求

    private func run(
        _ request: ChatRequest,
        continuation: AsyncThrowingStream<StreamResult, Error>.Continuation
    ) async throws {
        let key = Self.sanitizeAPIKey(request.apiKey)
        guard !key.isEmpty else { throw LLMError.missingAPIKey }

        guard let url = URL(string: Self.chatEndpoint(baseURL: request.baseURL)) else {
            throw LLMError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !key.isEmpty {
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.timeoutInterval = 120

        let kind = ProviderKind.detect(baseURL: request.baseURL)
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: Self.buildPayload(request: request, kind: kind)
        )

        // 带重定向代理的 session：某些中转会 302，跳转后需重新带上 Authorization
        let authHeader = urlRequest.value(forHTTPHeaderField: "Authorization") ?? ""
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        let session = URLSession(
            configuration: config,
            delegate: RedirectHandler(authHeader: authHeader),
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.decodeError("非 HTTP 响应")
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""

        // 非 2xx：读取响应体作为错误信息
        guard (200..<300).contains(http.statusCode) else {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 400 { break }
            }
            throw LLMError.httpError(http.statusCode, body)
        }

        // 回退：服务端忽略了 stream:true，直接返回完整 JSON
        if !contentType.contains("text/event-stream") {
            var collected = Data()
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if let d = (line + "\n").data(using: .utf8) { collected.append(d) }
            }
            if let text = Self.decodeNonStreamingContent(from: collected), !text.isEmpty {
                continuation.yield(StreamResult(
                    contentDelta: text, thinkingDelta: nil, isDone: false, error: nil
                ))
            } else if let body = String(data: collected, encoding: .utf8), !body.isEmpty {
                continuation.yield(StreamResult(
                    contentDelta: body, thinkingDelta: nil, isDone: false, error: nil
                ))
            }
            return
        }

        // SSE 分帧
        for try await line in bytes.lines {
            try Task.checkCancellation()

            // 兼容裸 `data:`（无空格）与 `data: `（含空格）两种写法
            guard let jsonString = Self.ssePayload(from: line) else { continue }

            if jsonString == "[DONE]" {
                continuation.yield(StreamResult(
                    contentDelta: nil, thinkingDelta: nil, isDone: true, error: nil
                ))
                return
            }

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else {
                continue  // keepalive 等非 JSON 行
            }

            let content = delta["content"] as? String
            // 思考内容：DeepSeek/千问 reasoning_content，OpenAI o系列 reasoning
            let thinking = (delta["reasoning_content"] as? String)
                ?? (delta["reasoning"] as? String)

            continuation.yield(StreamResult(
                contentDelta: content,
                thinkingDelta: thinking,
                isDone: false,
                error: nil
            ))
        }

        // 服务端未发 [DONE] 时的正常收尾
        continuation.yield(StreamResult(
            contentDelta: nil, thinkingDelta: nil, isDone: true, error: nil
        ))
    }

    // MARK: SSE 辅助

    /// 提取 SSE 的 data 载荷；非 data 行返回 nil
    static func ssePayload(from line: String) -> String? {
        if line.hasPrefix("data: ") {
            return String(line.dropFirst(6))
        }
        if line.hasPrefix("data:") {
            return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// 解析非流式完整响应，取 choices[0].message.content
    static func decodeNonStreamingContent(from data: Data) -> String? {
        struct Resp: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message?
            }
            let choices: [Choice]
        }
        guard let resp = try? JSONDecoder().decode(Resp.self, from: data) else { return nil }
        return resp.choices.first?.message?.content
    }

    // MARK: 端点与 payload

    /// 规范 baseURL：用户可能填根地址、/v1 或已带完整路径，统一拼到 chat/completions
    static func chatEndpoint(baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/chat/completions") { return base }
        return "\(base)/chat/completions"
    }

    /// 清洗 API Key：去引号、空白与零宽字符（粘贴易带入）
    static func sanitizeAPIKey(_ raw: String) -> String {
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if (key.hasPrefix("\"") && key.hasSuffix("\"")) || (key.hasPrefix("'") && key.hasSuffix("'")) {
            key = String(key.dropFirst().dropLast())
        }
        let zeroWidth: Set<UInt32> = [0x200B, 0x200C, 0x200D, 0xFEFF]
        let cleaned = key.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !zeroWidth.contains(scalar.value)
        }
        return String(String.UnicodeScalarView(cleaned))
    }

    /// 按 provider 构建 payload：核心字段各家一致，扩展参数分层注入
    static func buildPayload(request: ChatRequest, kind: ProviderKind) -> [String: Any] {
        var payload: [String: Any] = [
            "model": request.modelID,
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.text] },
            "stream": true
        ]

        if let temperature = request.temperature {
            payload["temperature"] = temperature
        }
        if let maxTokens = request.maxTokens {
            payload["max_tokens"] = maxTokens
        }

        switch kind {
        case .dashscope:
            // 千问 / 百炼：enable_search + enable_thinking + thinking_budget
            if request.enableSearch {
                payload["enable_search"] = true
                payload["search_options"] = ["enable_source": true]
            }
            if request.thinkingEffort != .off {
                payload["enable_thinking"] = true
                if let budget = request.thinkingEffort.dashscopeThinkingBudget {
                    payload["thinking_budget"] = budget
                }
            }

        case .openai, .generic:
            // OpenAI 官方及规范中转：reasoning_effort 档位 + web_search 工具
            if let effort = request.thinkingEffort.openAIReasoningEffort {
                payload["reasoning_effort"] = effort
            }
            if request.enableSearch {
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

// MARK: - 重定向代理

/// 跟随 3xx 重定向时重新附加 Authorization 头（跨域跳转默认会被丢弃）
final class RedirectHandler: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let authHeader: String

    init(authHeader: String) {
        self.authHeader = authHeader
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var req = request
        if !authHeader.isEmpty {
            req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        completionHandler(req)
    }
}
