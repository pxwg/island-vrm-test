import AppKit

enum NotchConfig {
    // 展开状态的大尺寸
    static let openSize = CGSize(width: 640, height: 190)
    static let shadowPadding: CGFloat = 20

    // 窗口物理尺寸
    static let windowSize = CGSize(
        width: openSize.width,
        height: openSize.height + shadowPadding
    )

    // 圆角配置
    static let radius = (
        opened: (top: 19.0, bottom: 24.0),
        closed: (top: 6.0, bottom: 14.0)
    )

    // --- 核心修改在这里 ---
    static var closedSize: CGSize {
        guard let screen = NSScreen.main else { return CGSize(width: 220, height: 32) }

        // 1. 获取物理刘海的预估宽度
        // 屏幕宽度 - 左菜单区域 - 右菜单区域 = 物理刘海区域
        var baseNotchWidth: CGFloat = 180 // 默认保底值
        if let left = screen.auxiliaryTopLeftArea?.width,
           let right = screen.auxiliaryTopRightArea?.width
        {
            baseNotchWidth = screen.frame.width - left - right
        }

        // 2. 定义我们要“加宽”多少来放头像
        let extraContentWidth: CGFloat = 90

        // 3. 计算最终宽度
        // 必须比物理刘海宽，内容才能露出来
        let finalWidth = baseNotchWidth + extraContentWidth

        // 4. 计算高度
        var height: CGFloat = 32
        if screen.safeAreaInsets.top > 0 {
            height = screen.safeAreaInsets.top
        } else {
            height = screen.frame.maxY - screen.visibleFrame.maxY
        }

        return CGSize(width: max(finalWidth, 200), height: height > 0 ? height : 32)
    }
}
