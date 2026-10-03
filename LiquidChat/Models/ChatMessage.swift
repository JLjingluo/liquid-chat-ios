import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var role: ChatRole
    var text: String
    var isThinking: Bool
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, text: String, isThinking: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.isThinking = isThinking
        self.timestamp = timestamp
    }
}

/// 会话状态：驱动顶部与空态切换
enum SessionState: Equatable {
    case idle
    case thinking        // 深度思考中
    case streaming
    case done
}

/// 模型选择：对应「深度思考」开关
enum LLMModel: String, CaseIterable, Identifiable {
    case flash = "deepseek-chat"
    case reasoner = "deepseek-reasoner"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "Flash"
        case .reasoner: return "深度思考 R1"
        }
    }
}
