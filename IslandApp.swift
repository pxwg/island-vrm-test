import IslandCore
import SwiftUI

// MARK: - Settings Window Manager

// 使用原生 NSWindow 管理器，解决 SwiftUI Window 在菜单栏应用中无法唤起的问题
class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var windowController: NSWindowController?

    func openSettings(viewModel: NotchViewModel?) {
        // 1. 如果窗口已经存在，直接激活并置顶
        if let controller = windowController, let window = controller.window {
            NSApp.activate(ignoringOtherApps: true) // 强制应用激活
            window.makeKeyAndOrderFront(nil) // 窗口置顶
            return
        }

        // 2. 如果窗口不存在，创建新的窗口
        // 注意：SettingsView 必须有 public init
        let settingsView = SettingsView(onBodyModeSelected: { isBodyMode in
            // 处理 God Mode 逻辑
            if let vm = viewModel {
                if isBodyMode {
                    vm.enterGodMode()
                } else {
                    vm.exitGodMode()
                }
            }
        })

        // 使用 NSHostingController 包装 SwiftUI 视图
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.sizingOptions = .preferredContentSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.center()
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false // 关闭时只隐藏，不销毁，保持状态

        // 创建 WindowController 并持有引用
        let controller = NSWindowController(window: window)
        windowController = controller

        // 3. 显示窗口
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Entry Point

@main
struct IslandVRMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Island VRM", systemImage: "figure.stand") {
            Button("Preferences...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command) // 绑定 Cmd+, 快捷键

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    func openSettings() {
        // 调用单例打开窗口，传入 viewModel 以便处理 God Mode
        SettingsWindowManager.shared.openSettings(viewModel: appDelegate.viewModel)
    }
}
