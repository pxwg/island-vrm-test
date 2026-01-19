import SwiftUI

class NotchViewModel: ObservableObject {
    enum State {
        case closed
        case expanded
    }

    @Published var state: State = .closed

    // [UI 数据源]
    @Published var chatContent: String = "你好！我是你的 AI 桌面助手。有什么可以帮你的吗？"
    @Published var currentTool: String? = nil // 例如 "Weather API"，为 nil 时不显示

    // 当前显示的灵动岛尺寸
    var currentSize: CGSize {
        state == .closed ? NotchConfig.closedSize : NotchConfig.openSize
    }

    // 当前的圆角 (用于 NotchShape)
    var currentTopRadius: CGFloat {
        state == .closed ? NotchConfig.radius.closed.top : NotchConfig.radius.opened.top
    }

    var currentBottomRadius: CGFloat {
        state == .closed ? NotchConfig.radius.closed.bottom : NotchConfig.radius.opened.bottom
    }

    func hoverStarted() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .expanded
        }
    }

    func hoverEnded() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state = .closed
        }
    }
}
