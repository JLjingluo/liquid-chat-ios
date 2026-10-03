import SwiftUI

// MARK: - 液态玻璃通用封装（iOS 26 真 API，低版本回退）

extension View {
    /// 液态玻璃卡片背景：iOS 26 用 .glassEffect，否则回退到毛玻璃
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// 液态玻璃胶囊：iOS 26 用胶囊形玻璃，否则回退
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// 圆形液态玻璃按钮背景
    @ViewBuilder
    func liquidGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}

// MARK: - 颜色常量（严格按截图取样）

enum Theme {
    /// 背景：#FDFDFD
    static let bg = Color(red: 0.992, green: 0.992, blue: 0.994)
    /// 文字主色：#161618
    static let textPrimary = Color(red: 0.086, green: 0.086, blue: 0.094)
    /// 次要文字：#8E8E93
    static let textSecondary = Color(red: 0.557, green: 0.557, blue: 0.576)
    /// 占位符：#B4B4B8
    static let placeholder = Color(red: 0.706, green: 0.706, blue: 0.722)
    /// 深度思考紫底：#F0EDFC
    static let chipPurpleBg = Color(red: 0.941, green: 0.929, blue: 0.988)
    /// 紫字：#5B4FD6
    static let chipPurpleText = Color(red: 0.357, green: 0.310, blue: 0.839)
    /// 搜索图标蓝：#3B7DD8
    static let searchBlue = Color(red: 0.231, green: 0.490, blue: 0.847)
    /// 气泡灰：#F0F0F2
    static let bubbleGray = Color(red: 0.941, green: 0.941, blue: 0.949)
    /// 品牌渐变（鲸鱼logo）
    static let brandGradient = LinearGradient(
        colors: [Color(red: 0.290, green: 0.490, blue: 1.0), Color(red: 0.482, green: 0.361, blue: 1.0)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - 弹簧动画（Q弹）

extension Animation {
    static let liquidBounce = Animation.spring(response: 0.32, dampingFraction: 0.62, blendDuration: 0.2)
    static let liquidFast = Animation.spring(response: 0.22, dampingFraction: 0.7, blendDuration: 0.15)
}
