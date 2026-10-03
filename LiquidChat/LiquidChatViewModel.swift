import ChatGPTUI
import ChatGPTSwift
import Foundation
import SwiftUI

/// ChatGPTUI 的 ViewModel 子类。
///
/// 为什么必须继承：`TextChatViewModel` 内部持有
/// `public let api: ChatGPTAPI`，而 `ChatGPTAPI` 的 baseURL 是
/// `private let urlString = "https://api.openai.com/v1"` 写死、构造器只收 apiKey，
/// 无法接DeepSeek / 千问等兼容端点。父类的 `send(text:)` 直接用这个 api 发请求，
/// 所以这里 override 掉 `send(text:)` / `retry(message:)` / `clearMessages()`，
/// 改走自有的 `OpenAICompatibleClient`（见 Services/LLMClient.swift）。
///
/// 复用 ChatGPTUI 的部分：消息模型（MessageRow/MessageRowType）、
/// Markdown 解析与代码高亮（ResponseParsingTask / AttributedView / CodeBlockView）。
@MainActor
final class LiquidChatViewModel: TextChatViewModel<Text> {

    // MARK: - App 侧配置

    @AppStorage("baseURL") private var baseURL = "https://api.deepseek.com/v1"
    @AppStorage("temperature") private var temperature = 0.6
    @AppStorage("maxTokens") private var maxTokens = 0
    @AppStorage("useTemperature") private var useTemperature = false
    @AppStorage("useMaxTokens") private var useMaxTokens = false
    @AppStorage("systemPrompt") private var systemPrompt = "You're a helpful assistant"

    /// 联网搜索开关（由 App 的 chip 控制）
    var enableSearch = false
    /// 思考档位（由 App 的 Think 选择器控制）
    var thinkingEffort: ThinkingEffort = .off

    private let client: LLMClient = OpenAICompatibleClient()

    /// 累积中的思考内容，用于渲染思考面板
    private(set) var thinkingText: String = ""

    init() {
        // 父类构造需要 apiKey；此处仅用于满足父类的存储初始化，
        // 实际请求不走父类的 ChatGPTAPI（已在 send 中完全覆盖）。
        super.init(apiKey: "")
        renderAsMarkdown = true
        useStreaming = true
    }

    private var apiKey: String { KeychainStore.readAPIKey() }

    /// 当前模型 ID 由 App 侧设置
    var modelID: String = ModelConfig.defaults[0].id

    // MARK: - 覆盖父类：走自有 LLMClient

    /// 覆盖父类发送逻辑。父类实现会调用硬编码 OpenAI 的 `api`，
    /// 这里改为使用 `OpenAICompatibleClient`，并分别累积正文与思考内容。
    override func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPrompting = true
        thinkingText = ""

        var messageRow = MessageRow<Text>(
            isPrompting: true,
            sendImage: senderImage,
            send: .rawText(trimmed),
            responseImage: botImage,
            response: .rawText(""),
            responseError: nil
        )
        messages.append(messageRow)

        let index = messages.count - 1
        let parsingTask = ResponseParsingTask()
        var streamText = ""
        var parsedLength = 0

        // 构造上下文：可选 system + 历史消息（排除刚追加的那条空回复）
        var context: [ChatMessage] = []
        let sys = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty {
            context.append(ChatMessage(role: .system, text: sys))
        }
        for row in messages.dropLast() {
            let question = row.sendText
            if !question.isEmpty {
                context.append(ChatMessage(role: .user, text: question))
            }
            if let reply = row.responseText, !reply.isEmpty {
                context.append(ChatMessage(role: .assistant, text: reply))
            }
        }

        let request = ChatRequest(
            messages: context,
            modelID: modelID,
            apiKey: apiKey,
            baseURL: baseURL,
            enableSearch: enableSearch,
            thinkingEffort: thinkingEffort,
            temperature: useTemperature ? temperature : nil,
            maxTokens: useMaxTokens ? maxTokens : nil
        )

        do {
            let stream = client.stream(request)

            for try await result in stream {
                try Task.checkCancellation()

                if let thinking = result.thinkingDelta, !thinking.isEmpty {
                    thinkingText += thinking
                }

                if let content = result.contentDelta, !content.isEmpty {
                    streamText += content

                    // 节流解析：累积够字数或遇到代码块再重新渲染 Markdown
                    if renderAsMarkdown {
                        let shouldReparse = streamText.count - parsedLength >= 64
                            || content.contains("```")
                            || content.contains("\n")
                        if shouldReparse {
                            let output = await parsingTask.parse(text: streamText)
                            parsedLength = streamText.count
                            messageRow.response = .attributed(output)
                        }
                    } else {
                        messageRow.response = .rawText(streamText)
                    }
                }

                messageRow.isPrompting = !result.isDone
                messages[index] = messageRow

                if result.isDone { break }
            }

            // 收尾：确保最终内容已解析
            if renderAsMarkdown {
                messageRow.response = .attributed(await parsingTask.parse(text: streamText))
            } else if streamText.isEmpty {
                messageRow.response = .rawText("")
            }

            // 流结束但正文为空且无报错 → 提示可能未开启流式
            messageRow.isPrompting = false
            messages[index] = messageRow
            isPrompting = false

        } catch is CancellationError {
            await finalize(messageRow, index: index, streamText: streamText, parsingTask: parsingTask)
            isPrompting = false
        } catch {
            // 保留已收到的部分内容，错误单独展示
            await finalize(messageRow, index: index, streamText: streamText, parsingTask: parsingTask)
            messageRow.responseError = error.localizedDescription
            messageRow.isPrompting = false
            messages[index] = messageRow
            isPrompting = false
        }
    }

    /// 停止生成：取消底层请求
    override func cancelStreamingResponse() {
        super.cancelStreamingResponse()
        isPrompting = false
    }

    /// 覆盖清空：父类会调用硬编码 OpenAI 的 `api.deleteHistoryList()`，此处不碰网络
    override func clearMessages() {
        withAnimation {
            messages = []
            thinkingText = ""
        }
        isPrompting = false
    }

    private func finalize(
        _ messageRow: MessageRow<Text>,
        index: Int,
        streamText: String,
        parsingTask: ResponseParsingTask
    ) async {
        var row = messageRow
        if renderAsMarkdown {
            row.response = .attributed(await parsingTask.parse(text: streamText))
        }
        row.isPrompting = false
        messages[index] = row
    }
}
