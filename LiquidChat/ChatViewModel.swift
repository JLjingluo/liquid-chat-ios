import SwiftUI

/// App 侧配置持有者：模型列表、输入框、搜索/思考开关。
/// 实际的对话与流式输出由 `LiquidChatViewModel`（ChatGPTUI 内核）负责。
@MainActor
class ChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var search = false
    @Published var thinkingEffort: ThinkingEffort = .off
    @Published var isRecording = false

    // 模型列表：持久化，可在设置里增删
    @Published var models: [ModelConfig] = ModelConfig.defaults
    @Published var currentModelID: String = ModelConfig.defaults[0].id

    @AppStorage("modelsJSON") private var modelsJSON = ""
    @AppStorage("currentModelID") private var savedModelID = ""

    var currentModel: ModelConfig {
        models.first { $0.id == currentModelID } ?? models[0]
    }

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

    // MARK: - 控制

    func toggleVoice() {
        withAnimation(.liquidFast) { isRecording.toggle() }
    }
}
