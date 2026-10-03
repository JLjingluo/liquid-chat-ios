import ChatGPTUI
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var chatVM = LiquidChatViewModel()
    @State private var showSettings = false
    @State private var showDrawer = false

    var body: some View {
        ZStack(alignment: .leading) {
            // 主界面
            VStack(spacing: 0) {
                TopBar(
                    models: vm.models,
                    currentModelID: $vm.currentModelID,
                    onMenu: { withAnimation(.liquidBounce) { showDrawer.toggle() } },
                    onNew: { newChat() }
                )

                // 消息区：采用 ChatGPTUI 的 MessageRowView 渲染
                // （Markdown + 代码高亮 + 错误重试），输入框保留自有的液态玻璃版本
                MessageListView(vm: chatVM)
                    .layoutPriority(1)

                ChatInputBar(
                    text: $vm.inputText,
                    search: $vm.search,
                    thinkingEffort: $vm.thinkingEffort,
                    isRecording: $vm.isRecording,
                    isGenerating: chatVM.isPrompting,
                    onSend: { send() },
                    onVoice: vm.toggleVoice
                )
            }
            .background(Theme.bg.ignoresSafeArea())
            .disabled(showDrawer)

            // 侧边抽屉
            if showDrawer {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.liquidBounce) { showDrawer = false } }

                DrawerView(
                    onSettings: {
                        withAnimation(.liquidBounce) { showDrawer = false }
                        showSettings = true
                    },
                    onNewChat: {
                        withAnimation(.liquidBounce) { showDrawer = false }
                        newChat()
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(vm: vm)
        }
        .onAppear {
            // 把 App 侧配置同步到 ChatGPTUI 的 ViewModel
            chatVM.modelID = vm.currentModel.id
            chatVM.enableSearch = vm.search
            chatVM.thinkingEffort = vm.thinkingEffort
        }
        .onChange(of: vm.currentModelID) { _, newValue in
            chatVM.modelID = newValue
        }
        .onChange(of: vm.search) { _, newValue in
            chatVM.enableSearch = newValue
        }
        .onChange(of: vm.thinkingEffort) { _, newValue in
            chatVM.thinkingEffort = newValue
        }
    }

    // MARK: - 发送

    private func send() {
        let trimmed = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !chatVM.isPrompting else { return }
        vm.inputText = ""
        Task { await chatVM.send(text: trimmed) }
    }

    private func newChat() {
        chatVM.clearMessages()
    }
}

// MARK: - 消息列表（ChatGPTUI 内核）

/// 用 ChatGPTUI 的 `MessageRowView` 渲染消息列表。
///
/// 为什么不用它的 `TextChatView`：该视图自带输入行、Divider 布局和固定白色背景，
/// 会与本App 保留的液态玻璃输入框重复渲染两套输入区。
/// 这里只取其核心渲染能力（Markdown + 代码高亮 + 出错重试），
/// 滚动与外层布局仍由 App 自己控制。
struct MessageListView: View {
    /// TextChatViewModel 继承自 @Observable 类，用 @Bindable 而非 @ObservedObject
    @Bindable var vm: LiquidChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { message in
                        MessageRowView(message: message) { message in
                            Task { @MainActor in
                                await vm.retry(message: message)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.last?.responseText) { _, _ in
                guard let last = vm.messages.last else { return }
                withAnimation(.liquidFast) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - 侧边抽屉

struct DrawerView: View {
    let onSettings: () -> Void
    let onNewChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 logo
            HStack(spacing: 10) {
                WhaleLogo(size: 34)
                Text("LiquidChat")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.top, 60)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            DrawerItem(icon: "square.and.pencil", title: "新对话", action: onNewChat)
            DrawerItem(icon: "gearshape", title: "设置（API Key）", action: onSettings)
            DrawerItem(icon: "info.circle", title: "关于", action: {})

            Spacer()

            Text("v1.0 · iOS 26 液态玻璃")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .top)
        .liquidGlass(cornerRadius: 0)
        .background(Theme.bg.opacity(0.9))
    }
}

struct DrawerItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
    }
}
