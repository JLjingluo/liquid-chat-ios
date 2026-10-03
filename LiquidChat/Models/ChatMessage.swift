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
    case thinking
    case streaming
    case done
}

// MARK: - 模型配置（用户可自定义任意 OpenAI 兼容模型）

struct ModelConfig: Identifiable, Codable, Equatable {
    var id: String       // API 模型名，如 gpt-5 / qwen3-max / deepseek-chat
    var name: String     // 显示名

    static let defaults: [ModelConfig] = [
        ModelConfig(id: "deepseek-chat", name: "DeepSeek Flash"),
        ModelConfig(id: "deepseek-reasoner", name: "DeepSeek R1"),
        ModelConfig(id: "qwen3-max", name: "Qwen3 Max"),
        ModelConfig(id: "gpt-5", name: "GPT-5")
    ]
}

// MARK: - 思考档位（关闭 / 低 / 中 / 高）

enum ThinkingEffort: String, CaseIterable, Identifiable, Codable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    /// OpenAI 官方（o系列 / GPT-5）reasoning_effort 参数值
    var openAIReasoningEffort: String? {
        switch self {
        case .off: return nil
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    /// 千问/百炼 thinking_budget（思考 token 上限）
    var dashscopeThinkingBudget: Int? {
        switch self {
        case .off: return nil
        case .low: return 1024
        case .medium: return 4096
        case .high: return 16384
        }
    }
}
