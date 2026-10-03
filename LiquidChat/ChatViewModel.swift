import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var search = false
    @Published var thinkingEffort: ThinkingEffort = .off
    @Published var isRecording = false
    @Published var state: SessionState = .idle
    @Published var thinkingText = ""
    @Published var errorMessage: String?
    @Published var showError = false

    // 模型列表：持久化，可在设置里增删
    @Published var models: [ModelConfig] = ModelConfig.defaults
    @Published var currentModelID: String = ModelConfig.defaults[0].id

    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("baseURL") var baseURL = "https://api.deepseek.com/v1"
    @AppStorage("modelsJSON") private var modelsJSON = ""
    @AppStorage("currentModelID") private var savedModelID = ""

    var currentModel: ModelConfig {
        models.first { $0.id == currentModelID } ?? models[0]
    }

    var greeting: String {
        messages.isEmpty ? "你好，让我们开始聊天吧" : ""
    }

    private var streamTask: Task<Void, Never>?

    init() {
        loadModels()
    }

    // MARK: - 模型持久化

    func loadModels() {
        if let data = modelsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ModelConfig].self, from: data),
           !decoded.isEmpty {
            models = decoded
        }
        if !savedModelID.isEmpty, models.contains(where: { $0.id == savedModelID }) {
            currentModelID = savedModelID
        }
    }

    func saveModels() {
        if let data = try? JSONEncoder().encode(models),
           let str = String(data: data, encoding: .utf8) {
            modelsJSON = str
        }
        savedModelID = currentModelID
    }

    func addModel(id: String, name: String) {
        let clean = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !models.contains(where: { $0.id == clean }) else { return }
        models.append(ModelConfig(id: clean, name: name.isEmpty ? clean : name))
        saveModels()
    }

    func removeModel(_ model: ModelConfig) {
        guard models.count > 1 else { return }
        models.removeAll { $0.id == model.id }
        if currentModelID == model.id { currentModelID = models[0].id }
        saveModels()
    }

    // MARK: - 发送

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, state == .idle else { return }

        let userMsg = ChatMessage(role: .user, text: trimmed)
        messages.append(userMsg)
        inputText = ""
        thinkingText = ""

        state = thinkingEffort != .off ? .thinking : .streaming

        streamTask = Task {
            await performStream()
        }
    }

    private func performStream() async {
        do {
            let request = LLMService.ChatRequest(
                messages: messages,
                modelID: currentModelID,
                apiKey: apiKey,
                baseURL: baseURL,
                enableSearch: search,
                thinkingEffort: thinkingEffort
            )
            let stream = await LLMService.shared.chatStream(request)

            var assistantMsg = ChatMessage(role: .assistant, text: "", isThinking: thinkingEffort != .off)
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
    }
}
