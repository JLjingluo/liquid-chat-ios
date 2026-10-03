import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var model: LLMModel = .flash
    @Published var deepThink = false
    @Published var search = false
    @Published var isRecording = false
    @Published var state: SessionState = .idle
    @Published var thinkingText = ""
    @Published var errorMessage: String?
    @Published var showError = false

    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("baseURL") var baseURL = "https://api.deepseek.com"

    var greeting: String {
        messages.isEmpty ? "你好，让我们开始聊天吧" : ""
    }

    private var streamTask: Task<Void, Never>?

    // MARK: - 发送

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, state == .idle else { return }

        let userMsg = ChatMessage(role: .user, text: trimmed)
        messages.append(userMsg)
        inputText = ""
        thinkingText = ""

        state = model == .reasoner ? .thinking : .streaming

        streamTask = Task {
            await performStream()
        }
    }

    private func performStream() async {
        do {
            let stream = await LLMService.shared.chatStream(
                messages: messages,
                model: model,
                apiKey: apiKey,
                baseURL: baseURL
            )

            var assistantMsg = ChatMessage(role: .assistant, text: "", isThinking: model == .reasoner)
            messages.append(assistantMsg)
            let msgIndex = messages.count - 1

            var fullContent = ""
            var fullThinking = ""

            for try await result in stream {
                if Task.isCancelled { break }

                if let error = result.error {
                    state = .idle
                    errorMessage = error.localizedDescription
                    showError = true
                    messages[msgIndex].isThinking = false
                    return
                }

                if result.isDone {
                    state = .done
                    messages[msgIndex].isThinking = false
                    return
                }

                if let thinking = result.thinkingDelta {
                    fullThinking += thinking
                    thinkingText = fullThinking
                }

                if let content = result.contentDelta {
                    fullContent += content
                    messages[msgIndex].text = fullContent
                    if state == .thinking { state = .streaming }
                }
            }

            state = .done
            messages[msgIndex].isThinking = false
        } catch {
            state = .idle
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - 控制

    func newChat() {
        streamTask?.cancel()
        withAnimation(.liquidBounce) {
            messages = []
            state = .idle
            thinkingText = ""
        }
    }

    func toggleVoice() {
        withAnimation(.liquidFast) { isRecording.toggle() }
        // TODO: 接入语音识别
    }
}
