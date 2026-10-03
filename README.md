# LiquidChat — iOS 26 液态玻璃 AI 客户端

> 1:1 复刻极简 AI 聊天界面，SwiftUI 原生 + iOS 26 Liquid Glass，云端编译出 unsigned IPA，你自己签名安装。

---

## 一、这是什么

一个**可直接运行**的 iOS 聊天客户端，界面严格 1:1 复刻主流 AI 助手（DeepSeek / 豆包）的极简风格：

- 纯白背景 `#FDFDFD`，无多余装饰
- 顶部居中模型选择器「Qwen3.8 Flash ⌄」
- 底部悬浮输入框 + 液态玻璃胶囊
- 深度思考 / 智能搜索 / 锤头工具 chip
- iOS 26 **真·液态玻璃**（`.glassEffect()` API），非模拟

**接入方式**：设置里填 API Key，直接调 **DeepSeek**（默认）或**千问**（改 Base URL）的 OpenAI 兼容接口，支持流式输出和 R1 思考过程展示。

---

## 二、交付物结构

```
liquid-chat-ios/
├── project.yml                    # XcodeGen 项目定义（iOS 26）
├── .github/workflows/
│   └── build-ipa.yml              # GitHub Actions 云端编译
└── LiquidChat/
    ├── LiquidChatApp.swift        # App 入口
    ├── ContentView.swift          # 主界面 + 抽屉
    ├── ChatViewModel.swift        # 业务逻辑（发送/流式/状态）
    ├── SettingsView.swift         # API Key / Base URL 设置
    ├── Info.plist
    ├── Models/
    │   └── ChatMessage.swift      # 消息模型 + 会话状态 + 模型枚举
    ├── Services/
    │   └── LLMService.swift       # OpenAI 兼容流式 API 客户端
    └── Views/
        ├── LiquidGlass.swift      # iOS 26 液态玻璃封装 + 主题色
        ├── Components.swift       # 玻璃按钮/模型选择器/chip/输入框
        └── ChatViews.swift        # 空态/气泡/思考卡/顶栏
```

---

## 三、云端编译出 IPA（推荐）

### 步骤 1：把代码推到你的 GitHub 仓库

```bash
cd liquid-chat-ios
git init
git add -A
git commit -m "feat: LiquidChat iOS 26 liquid glass"
git branch -M main
git remote add origin https://github.com/你的用户名/liquid-chat-ios.git
git push -u origin main
```

> 私有仓库也可以，GitHub Actions 免费额度内（每月 2000 分钟，构建一次约 5-8 分钟）。

### 步骤 2：触发构建

**自动**：push 到 `main` 分支自动触发。

**手动**：GitHub 仓库页面 → **Actions** → **Build unsigned IPA** → **Run workflow**。

### 步骤 3：下载 IPA

构建完成后，Actions 页面 → 最近一次运行 → **Artifacts** 下载 `LiquidChat-unsigned-ipa`。

解压得到 `Payload/LiquidChat.app`。

---

## 四、签名并安装（你负责）

构建出来的是**未签名**的 `.app`，需要你用以下任一方式签名：

| 方式 | 有效期 | 说明 |
|---|---|---|
| **Sideloadly** | 7 天 | Windows/Mac 均可，免费 Apple ID 签名，最省事 |
| **爱思助手** | 7 天 | iPhone 直连导入 |
| **AltStore / SideStore** | 7 天 | 需电脑常驻，可自动续签 |
| **付费开发者证书** | 1 年 | 自己用 Xcode 重签或企业签 |

**Sideloadly 流程（推荐）**：

1. 下载 [Sideloadly](https://sideloadly.io/)
2. 用数据线连 iPhone，信任电脑
3. 把 `LiquidChat-unsigned.ipa` 拖进 Sideloadly
4. 填你的 Apple ID（免费账号即可）
5. Start → 等待签名安装
6. 手机上：设置 → 通用 → VPN与设备管理 → 信任开发者

> 7 天后过期，重新拖一次即可。要 1 年有效，需要付费 Apple Developer 账号。

---

## 五、接入 API

### DeepSeek（默认）

1. 打开 [DeepSeek 开放平台](https://platform.deepseek.com/)
2. 创建 API Key
3. App 里：左上角菜单 → 设置 → 粘贴 API Key
4. Base URL 保持默认 `https://api.deepseek.com`

### 千问 Qwen

1. 打开 [阿里云百炼](https://bailian.console.aliyun.com/)
2. 创建 API Key
3. App 里：设置 → Base URL 改成 `https://dashscope.aliyuncs.com/compatible-mode/v1`
4. 粘贴千问 API Key

---

## 六、界面 1:1 对照表

| 元素 | 实现 | 规格 |
|---|---|---|
| 背景 | `Theme.bg` | `#FDFDFD` |
| 顶栏左按钮 | `GlassCircleButton` | 40px 圆，液态玻璃 |
| 顶栏标题 | `ModelSelector` | 16.5px 粗体 + chevron |
| 顶栏右按钮 | `GlassCircleButton` | 三点菜单 |
| 空态 | `EmptyStateView` | 居中 logo + 欢迎语 |
| 输入框 | `ChatInputBar` | 液态玻璃，圆角 26px |
| 占位符 | `placeholder` | 「说点什么...」`#B4B4B8` |
| 搜索 chip | `GlassChip` | 淡紫底 `#F0EDFC` + 紫字 `#5B4FD6` |
| 锤头 chip | 圆形 `Button` | 淡紫底，激活变紫实心 |
| Think 下拉 | `Button` | 15px + chevron |
| 麦克风 | `GlassCircleButton` | 液态玻璃圆按钮 |
| 气泡（用户） | `MessageBubble` | 深色 `#161618` 白字 |
| 气泡（AI） | `MessageBubble` | 浅灰 `#F0F0F2` |
| 深度思考卡 | `ThinkingCard` | 液态玻璃 + 思考过程 |
| 动效 | `.liquidBounce` | spring(0.32, 0.62) Q弹 |

---

## 七、联网搜索（已实装，非占位）

「智能搜索」chip 是**真实功能**，不是占位。开启后按 provider 自动注入对应参数：

| Provider | 端点 | 注入参数 | 说明 |
|---|---|---|---|
| **千问 Qwen** | `dashscope.aliyuncs.com/compatible-mode/v1` | `enable_search: true` + `search_options` | ✅ 官方原生支持 |
| **阿里云百炼托管模型** | `*.maas.aliyuncs.com` / `*.aliyuncs.com` | `enable_search: true` | ✅ 含 deepseek-v4、glm-5.2、kimi-k3 |
| **DeepSeek 官方** | `api.deepseek.com` | 不注入 | ⚠️ 其 `/chat/completions` 无此参数，需走 Responses API |

**代码自动判断**（`LLMService.supportsSearchParam`）：检测到 `dashscope` / `aliyuncs` / `maas` / `qwencloud` 域名时注入 `enable_search`，避免向不支持的端点发未知参数报错。

**搜索结果展示**：千问返回 `search_results` 时会带引用来源，当前 UI 显示回答正文；来源列表展示可后续加（`search_info` 字段已可获取）。

> 修正说明：此前误标「智能搜索为 UI 占位」，实际千问/百炼 API 原生支持，已改为真实注入。

## 八、iOS 26 液态玻璃说明
|---|---|---|
| `.glassEffect(.regular, in: .rect(...))` | 卡片/输入框 | 26+ |
| `.glassEffect(.regular, in: .capsule)` | 胶囊按钮 | 26+ |
| `.glassEffect(.regular.interactive(), in: .circle)` | 可交互圆按钮 | 26+ |
| 回退 | `.ultraThinMaterial` | < 26 |

所有玻璃组件在 `LiquidGlass.swift` 里封装，低版本自动回退到毛玻璃，不会崩。

---

## 九、常见问题

| 问题 | 原因 | 解决 |
|---|---|---|
| Actions 构建失败 | XcodeGen 未装或版本低 | workflow 已 `brew install xcodegen`，重跑即可 |
| `xcodebuild` 报签名错 | 忘了关签名 | 已设 `CODE_SIGNING_ALLOWED=NO`，正常 |
| 装到手机打不开 | 未信任开发者 | 设置 → 通用 → VPN与设备管理 → 信任 |
| 7 天后闪退 | 免费证书过期 | Sideloadly 重新签名安装 |
| 深度思考不显示过程 | 模型选成 Flash | 切换「深度思考 R1」或点锤头 chip |
| 智能搜索无结果 | 端点不支持该参数 | 改用千问/百炼端点，DeepSeek 官方需 Responses API |
| 千问连不上 | Base URL 没改 | 设置里改成千问兼容地址 |

---

## 十、技术栈

- **语言**：Swift 6（strict concurrency）
- **UI**：SwiftUI + iOS 26 Liquid Glass
- **网络**：`URLSession.bytes` 流式 SSE
- **架构**：MVVM（`@MainActor` + `ObservableObject`）
- **项目生成**：XcodeGen（`project.yml`）
- **CI**：GitHub Actions `macos-26` + Xcode 26.0.1

> 参考开源项目：Agmente（SwiftUI 结构）、happy（交互逻辑），均为 MIT 许可。
