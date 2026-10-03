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
    @Binding var model: LLMModel
    @State private var expanded = false

    var body: some View {
        Button(action: {
            withAnimation(.liquidBounce) { expanded.toggle() }
        }) {
            HStack(spacing: 5) {
                Text(model.displayName)
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
        .confirmationDialog("选择模型", isPresented: $expanded, titleVisibility: .hidden) {
            ForEach(LLMModel.allCases) { m in
                Button(m.displayName) {
                    withAnimation(.liquidFast) { model = m }
                }
            }
            Button("取消", role: .cancel) {}
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
    @Binding var deepThink: Bool
    @Binding var search: Bool
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

                    // 锤头工具 chip
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.liquidFast) { deepThink.toggle() }
                    }) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(deepThink ? Color.white : Theme.chipPurpleText)
                            .frame(width: 31, height: 31)
                            .background(
                                Circle().fill(deepThink ? Theme.chipPurpleText : Theme.chipPurpleBg)
                            )
                    }

                    Spacer()

                    // Think 下拉
                    Button(action: {}) {
                        HStack(spacing: 3) {
                            Text("Think")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 31)
                    }

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
