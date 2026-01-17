import SwiftUI

class NotchViewModel: ObservableObject {
    enum State {
        case closed
        case expanded
    }

    @Published var state: State = .closed

    // 当前显示的尺寸
    var currentSize: CGSize {
        state == .closed ? NotchConfig.closedSize : NotchConfig.openSize
    }

    // 当前的圆角 (用于传递给 NotchShape)
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
