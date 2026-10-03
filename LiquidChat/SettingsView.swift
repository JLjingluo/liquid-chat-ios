import SwiftUI

// MARK: - 设置页（API + 模型管理）

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("baseURL") private var baseURL = "https://api.deepseek.com/v1"

    @Environment(\.dismiss) private var dismiss
    @State private var tempKey = ""
    @State private var tempURL = ""

    // 模型管理：用 ViewModel 共享，设置里改完同步主界面
    @ObservedObject var vm: ChatViewModel

    @State private var newModelID = ""
    @State private var newModelName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key（sk-...）", text: $tempKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                } header: {
                    Text("API 密钥")
                } footer: {
                    Text("保存在本机，不会上传。支持任意 OpenAI 兼容服务商。")
                }

                Section {
                    TextField("Base URL", text: $tempURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("API 地址")
                } footer: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DeepSeek: https://api.deepseek.com/v1")
                        Text("千问: https://dashscope.aliyuncs.com/compatible-mode/v1")
                        Text("OpenAI: https://api.openai.com/v1")
                        Text("OpenRouter: https://openrouter.ai/api/v1")
                    }
                    .font(.caption)
                }

                Section {
                    ForEach(vm.models) { m in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name)
                                    .font(.system(size: 15.5, weight: .medium))
                                Text(m.id)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if vm.currentModelID == m.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.chipPurpleText)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { vm.currentModelID = m.id }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { vm.removeModel(vm.models[$0]) }
                    }

                    // 添加新模型
                    VStack(spacing: 8) {
                        TextField("模型 ID（如 gpt-5 / qwen3-max）", text: $newModelID)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        TextField("显示名（可选）", text: $newModelName)
                        Button("添加模型") {
                            vm.addModel(id: newModelID, name: newModelName)
                            newModelID = ""
                            newModelName = ""
                        }
                        .disabled(newModelID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("模型列表")
                } footer: {
                    Text("点选设为当前模型，左滑删除。可添加任意 OpenAI 兼容模型 ID。")
                }

                Section {
                    HStack {
                        Text("当前 Provider")
                        Spacer()
                        Text(providerName)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("按 Base URL 自动识别，决定联网搜索与思考档位的参数格式。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        apiKey = tempKey
                        baseURL = tempURL
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempKey = apiKey
                tempURL = baseURL
            }
        }
    }

    private var providerName: String {
        switch LLMService.ProviderKind.detect(baseURL: tempURL) {
        case .dashscope: return "千问 / 阿里云百炼"
        case .deepseek: return "DeepSeek 官方"
        case .openai: return "OpenAI 官方 / Azure"
        case .generic: return "通用 OpenAI 兼容"
        }
    }
}
