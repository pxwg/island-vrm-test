import Cocoa
import SwiftUI

class NotchWindow: NSPanel {
    init() {
        // 1. 使用最大尺寸 (展开时的大小)
        let size = NotchConfig.windowSize
        guard let screen = NSScreen.main else { fatalError("No screen found") }
        let screenRect = screen.frame
        // 2. 计算位置：顶部居中
        let x = screenRect.midX - (size.width / 2)
        let y = screenRect.maxY - size.height
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        // 3. 核心属性设置
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        hasShadow = false

        // 4. 层级设置
        level = .mainMenu + 3

        // 5. 集合行为
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

public class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NotchWindow!
    public var viewModel: NotchViewModel?

    public func applicationDidFinishLaunching(_: Notification) {
        _ = SharedWebViewHelper.shared

        window = NotchWindow()
        let vm = NotchViewModel()
        viewModel = vm
        let contentView = NotchView(vm: vm)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = .minSize
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
    }
}
