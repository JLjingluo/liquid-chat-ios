import SwiftUI

// MARK: - 设置页（API Key + Base URL）

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("baseURL") private var baseURL = "https://api.deepseek.com"
    @AppStorage("modelName") private var modelName = "deepseek-chat"

    @Environment(\.dismiss) private var dismiss
    @State private var tempKey = ""
    @State private var tempURL = ""

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
                    Text("从 DeepSeek / 千问控制台获取。保存在本机，不会上传。")
                }

                Section {
                    TextField("Base URL", text: $tempURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("API 地址")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DeepSeek: https://api.deepseek.com")
                        Text("千问: https://dashscope.aliyuncs.com/compatible-mode/v1")
                    }
                    .font(.caption)
                }

                Section {
                    Picker("模型", selection: $modelName) {
                        Text("deepseek-chat").tag("deepseek-chat")
                        Text("deepseek-reasoner").tag("deepseek-reasoner")
                    }
                } header: {
                    Text("默认模型")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        apiKey = tempKey
                        baseURL = tempURL
                        dismiss()
                    }
                    .disabled(tempKey.isEmpty)
                }
            }
            .onAppear {
                tempKey = apiKey
                tempURL = baseURL
            }
        }
    }
}
