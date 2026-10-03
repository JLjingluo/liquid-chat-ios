import SwiftUI

// MARK: - 圆形玻璃按钮（对应截图左右两侧）

struct GlassCircleButton: View {
    let systemName: String
    let action: () -> Void
    var size: CGFloat = 40
    var iconSize: CGFloat = 19
    @State private var pressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
        }
        .buttonStyle(GlassButtonStyle())
        .liquidGlassCircle()
        .scaleEffect(pressed ? 0.88 : 1)
        .animation(.liquidFast, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - 模型选择器（对应截图顶部「Qwen3.8 Flash ⌄」）

struct ModelSelector: View {
    let models: [ModelConfig]
    @Binding var currentModelID: String
    @State private var expanded = false

    private var currentName: String {
        models.first { $0.id == currentModelID }?.name ?? models.first?.name ?? "模型"
    }

    var body: some View {
        Button(action: {
            withAnimation(.liquidBounce) { expanded.toggle() }
        }) {
            HStack(spacing: 5) {
                Text(currentName)
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .confirmationDialog("选择模型", isPresented: $expanded, titleVisibility: .visible) {
            ForEach(models) { m in
                Button(m.name) {
                    withAnimation(.liquidFast) { currentModelID = m.id }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - Think 思考档位选择器（关闭/低/中/高）

struct ThinkSelector: View {
    @Binding var effort: ThinkingEffort

    var body: some View {
        Menu {
            ForEach(ThinkingEffort.allCases) { level in
                Button(action: {
                    withAnimation(.liquidFast) { effort = level }
                }) {
                    HStack {
                        Text(level.displayName)
                        if effort == level {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("Think")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(effort == .off ? Theme.textPrimary : Theme.chipPurpleText)
                if effort != .off {
                    Text(effort.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.chipPurpleText)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 9)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(effort == .off ? Color.clear : Theme.chipPurpleBg)
            )
        }
    }
}

// MARK: - 胶囊 Chip（深度思考 / 智能搜索）

struct GlassChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    let iconColor: Color
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.liquidFast) { action() }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? iconColor : Theme.textSecondary)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? Theme.chipPurpleText : Theme.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 11)
            .frame(height: 31)
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? Theme.chipPurpleBg : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isActive ? Color.clear : Color.black.opacity(0.07), lineWidth: 0.5)
        )
        .scaleEffect(pressed ? 0.92 : 1)
        .animation(.liquidFast, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - 输入区（严格复刻底部胶囊输入框）

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var search: Bool
    @Binding var thinkingEffort: ThinkingEffort
    @Binding var isRecording: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    let onVoice: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 输入框主体
            VStack(spacing: 10) {
                // 文本区
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("说点什么...")
                            .font(.system(size: 16.5))
                            .foregroundStyle(Theme.placeholder)
                            .padding(.horizontal, 4)
                            .padding(.top, 1)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 16.5))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minHeight: 24, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($focused)
                        .submitLabel(.send)
                }

                // 底部工具行
                HStack(spacing: 8) {
                    // 附件按钮
                    GlassCircleButton(systemName: "plus", action: {}, size: 31, iconSize: 18)

                    // 智能搜索 chip
                    GlassChip(
                        icon: "magnifyingglass",
                        label: "搜索",
                        isActive: search,
                        iconColor: Theme.searchBlue,
                        action: { search.toggle() }
                    )

                    Spacer()

                    // Think 档位
                    ThinkSelector(effort: $thinkingEffort)

                    // 麦克风
                    GlassCircleButton(
                        systemName: isRecording ? "stop.fill" : "mic.fill",
                        action: onVoice,
                        size: 31,
                        iconSize: 17
                    )
                }
            }
            .padding(.horizontal, 13)
            .padding(.top, 12)
            .padding(.bottom, 11)
            .liquidGlass(cornerRadius: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.075), lineWidth: 1)
            )

            // 发送按钮（有文字时浮现）
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating {
                HStack {
                    Spacer()
                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.textPrimary))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                .padding(.top, 8)
            }
        }
        .animation(.liquidBounce, value: text.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
