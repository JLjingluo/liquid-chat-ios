import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var showSettings = false
    @State private var showDrawer = false

    var body: some View {
        ZStack(alignment: .leading) {
            // 主界面
            VStack(spacing: 0) {
                TopBar(
                    model: $vm.model,
                    onMenu: { withAnimation(.liquidBounce) { showDrawer.toggle() } },
                    onNew: { vm.newChat() }
                )

                // 消息区
                ScrollViewReader { proxy in
                    ScrollView {
                        if vm.messages.isEmpty {
                            EmptyStateView(greeting: vm.greeting)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(vm.messages) { msg in
                                    MessageBubble(message: msg)
                                        .id(msg.id)
                                }
                                if !vm.thinkingText.isEmpty {
                                    ThinkingCard(text: vm.thinkingText)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation(.liquidFast) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                ChatInputBar(
                    text: $vm.inputText,
                    deepThink: $vm.deepThink,
                    search: $vm.search,
                    isRecording: $vm.isRecording,
                    isGenerating: vm.state != .idle,
                    onSend: vm.send,
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
                        vm.newChat()
                    }
                )
                .transition(.move(edge: .leading))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("出错了", isPresented: $vm.showError) {
            Button("好的") {}
        } message: {
            Text(vm.errorMessage ?? "未知错误")
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
