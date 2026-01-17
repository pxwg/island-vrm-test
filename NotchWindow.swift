import Cocoa
import SwiftUI

class NotchWindow: NSPanel {
    init() {
        // 使用预定义的最大尺寸
        let size = NotchConfig.windowSize

        // 计算居中、吸顶的位置
        // 注意：macOS 坐标系原点在屏幕左下角
        // y = screenHeight - windowHeight，这样窗口顶部才会贴着屏幕顶部
        guard let screen = NSScreen.main else { fatalError("No screen found") }
        let screenRect = screen.frame
        let x = screenRect.midX - (size.width / 2)
        let y = screenRect.maxY - size.height

        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel], // 无边框，不激活
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .mainMenu + 3 // 确保覆盖在菜单栏之上
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovable = false

        // 关键：让鼠标点击穿透透明区域，但灵动岛本身可以接收事件
        // 实际上因为我们窗口是固定大小的，SwiftUI 的 contentShape 会处理内部交互
        // 这里设置为 false 允许 View 接收事件
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { false }
}

// 在 AppDelegate 或 App 入口中使用
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NotchWindow!

    func applicationDidFinishLaunching(_: Notification) {
        window = NotchWindow()
        let contentView = NotchView()

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = .minSize // 允许 View 自由调整大小
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
    }
}
