import SwiftUI

struct NotchView: View {
    @StateObject var vm: NotchViewModel

    // [继承配置] 动态计算展开时 WebView 的宽度 (50%)
    private let expandedWebWidth: CGFloat = NotchConfig.openSize.width * 0.5

    // [继承配置] 动态计算闭合时的 Padding (实现垂直居中)
    // 公式：(灵动岛高度 - 头像高度) / 2
    private var closedPadding: CGFloat {
        (NotchConfig.closedSize.height - NotchConfig.VRM.headSize.height) / 2
    }

    init(vm: NotchViewModel = NotchViewModel()) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        // 1. 全局容器：吸顶
        ZStack(alignment: .top) {
            // 2. 灵动岛主体 Stack
            ZStack(alignment: .top) {
                // --- Layer A: 背景层 (黑色实体 + 阴影) ---
                // 这一层独立出来，是为了阴影不被下面的 clipShape 裁掉
                NotchShape(
                    topCornerRadius: vm.currentTopRadius,
                    bottomCornerRadius: vm.currentBottomRadius
                )
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .frame(width: vm.currentSize.width, height: vm.currentSize.height)

                // --- 内容容器 (WebView + UI) ---
                // 将内容层打包，统一进行形状裁剪，确保边缘完美相切
                ZStack(alignment: .top) {
                    // --- Layer B: 3D 模型 (WebView) ---
                    VRMWebView(state: vm.state)
                        .frame(
                            // 宽度：闭合时用 headSize，展开时用 50% 宽度
                            width: vm.state == .closed ? NotchConfig.VRM.headSize.width : expandedWebWidth,
                            // 高度：闭合时用 headSize，展开时填满整个灵动岛高度
                            height: vm.state == .closed ? NotchConfig.VRM.headSize.height : NotchConfig.openSize.height
                        )
                        // [关键修改] Padding 逻辑
                        // 闭合时：使用动态计算的 padding 居中
                        // 展开时：padding 为 0，配合外层的 clipShape 实现边缘贴合 (相切)
                        .padding(.top, vm.state == .closed ? closedPadding : 0)
                        .padding(.trailing, vm.state == .closed ? closedPadding : 0)
                        .frame(
                            width: vm.currentSize.width,
                            height: vm.currentSize.height,
                            alignment: .topTrailing // 始终右上角对齐
                        )
                        .zIndex(2)

                    // --- Layer C: UI 内容 ---
                    ZStack(alignment: .top) {
                        // 1. 展开态内容
                        ExpandedContent(vm: vm, webViewWidth: expandedWebWidth)
                            .frame(width: NotchConfig.openSize.width, height: NotchConfig.openSize.height)
                            .scaleEffect(vm.state == .expanded ? 1.0 : 0.5, anchor: .top)
                            .opacity(vm.state == .expanded ? 1.0 : 0.0)
                            .offset(y: vm.state == .expanded ? 0 : 15)
                            .allowsHitTesting(vm.state == .expanded)

                        // 2. 折叠态内容
                        CompactView(webViewWidth: NotchConfig.VRM.headSize.width, padding: closedPadding)
                            .frame(width: NotchConfig.closedSize.width, height: NotchConfig.closedSize.height)
                            .scaleEffect(vm.state == .closed ? 1.0 : 1.2, anchor: .center)
                            .opacity(vm.state == .closed ? 1.0 : 0.0)
                            .allowsHitTesting(vm.state == .closed)
                    }
                    .frame(width: vm.currentSize.width, height: vm.currentSize.height, alignment: .top)
                    .zIndex(3)
                }
                // [核心] 对内容容器进行裁切，确保 WebView 在 Padding=0 时能完美贴合灵动岛边缘
                .clipShape(NotchShape(
                    topCornerRadius: vm.currentTopRadius,
                    bottomCornerRadius: vm.currentBottomRadius
                ))
            }
            .contentShape(Rectangle()) // 确保透明区域也能响应鼠标 Hover
            .onHover { hovering in
                if hovering { vm.hoverStarted() }
                else { vm.hoverEnded() }
            }
        }
        .frame(width: NotchConfig.windowSize.width, height: NotchConfig.windowSize.height, alignment: .top)
        .ignoresSafeArea()
    }
}

// --- 子视图组件 ---

struct CompactView: View {
    // 接收动态计算的参数，用于布局避让
    var webViewWidth: CGFloat
    var padding: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                Text("24°")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.leading, 14)

            Spacer()
            // 中间避让物理刘海 (这里可以进一步优化为 NotchConfig 计算，暂时保持硬编码或逻辑)
            Spacer().frame(width: 100)
            Spacer()

            // 右侧避让 WebView 的位置
            // 宽度 = Head宽 + 右侧Padding
            Spacer().frame(width: webViewWidth + padding)
        }
        .frame(height: NotchConfig.closedSize.height)
    }
}

struct ExpandedContent: View {
    @ObservedObject var vm: NotchViewModel
    var webViewWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Assistant")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let tool = vm.currentTool {
                        HStack(spacing: 4) {
                            Image(systemName: "hammer.fill")
                            Text(tool)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }

                ScrollView {
                    Text(vm.chatContent)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                HStack {
                    Button(action: {}) {
                        Label("Chat", systemImage: "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                }
            }
            .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 右侧留白，宽度完全等于 WebView 的宽度
            Spacer().frame(width: webViewWidth)
        }
        // 顶部避让，使用闭合状态的高度作为 Padding
        .padding(.top, NotchConfig.closedSize.height)
    }
}

// --- 预览 ---

#Preview("展开状态") {
    NotchView(vm: NotchViewModel(isPreview: true))
        .frame(width: 800, height: 400)
        .background(Color.black.opacity(0.1))
}

#Preview("收起状态") {
    let vm = NotchViewModel(isPreview: true)
    vm.state = .closed
    return NotchView(vm: vm)
        .frame(width: 500, height: 200)
}
