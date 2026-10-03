import SwiftUI

// MARK: - 品牌 Logo（鲸鱼，简化矢量）

struct WhaleLogo: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Theme.brandGradient)
                .frame(width: size, height: size)
                .shadow(color: Theme.searchBlue.opacity(0.28), radius: size * 0.14, y: size * 0.06)

            // 鲸鱼剪影
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 空态（严格复刻：logo + 欢迎语）

struct EmptyStateView: View {
    let greeting: String

    var body: some View {
        VStack(spacing: 16) {
            WhaleLogo(size: 56)
            Text(greeting)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

// MARK: - 消息气泡

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 16.5))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(message.role == .user ? Theme.textPrimary : Theme.bubbleGray)
                    )
                    .foregroundStyle(message.role == .user ? Color.white : Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                if message.isThinking {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("深度思考中...")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 5)
    }
}

// MARK: - 思考过程卡片（深度思考时显示）

struct ThinkingCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 14)
        .padding(.horizontal, 18)
        .padding(.vertical, 5)
    }
}

// MARK: - 顶栏（严格复刻）

struct TopBar: View {
    let models: [ModelConfig]
    @Binding var currentModelID: String
    let onMenu: () -> Void
    let onNew: () -> Void

    var body: some View {
        ZStack {
            HStack {
                GlassCircleButton(systemName: "line.3.horizontal", action: onMenu)
                Spacer()
                GlassCircleButton(systemName: "ellipsis", action: onNew)
            }
            .padding(.horizontal, 20)

            ModelSelector(models: models, currentModelID: $currentModelID)
        }
        .frame(height: 52)
    }
}
