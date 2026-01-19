import SwiftUI

struct NotchView: View {
    @StateObject var vm = NotchViewModel()

    var body: some View {
        // [关键修复] 1. 最外层容器：必须填满整个透明 Window，并强制顶部对齐
        // 这样内容才会始终“吸”在屏幕顶部，而不是浮在 Window 中间
        ZStack(alignment: .top) {
            // 2. 灵动岛动态容器：尺寸跟随 vm.currentSize 变化，产生展开/收起动画
            ZStack(alignment: .top) {
                // 背景形状
                NotchShape(
                    topCornerRadius: vm.currentTopRadius,
                    bottomCornerRadius: vm.currentBottomRadius
                )
                .fill(Color.black)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)

                // 3. 内容层 (根据状态切换)
                if vm.state == .closed {
                    // === [折叠状态 UI] ===
                    HStack(spacing: 0) {
                        // 左侧信息
                        HStack(spacing: 6) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            // Text("24°")
                            //     .font(.system(size: 12, weight: .medium))
                            //     .foregroundColor(.white)
                        }
                        .padding(.leading, 14)

                        Spacer()

                        // 中间避让物理刘海区域 (根据实际机型调整占位)
                        Spacer().frame(width: 100)

                        Spacer()

                        // 右侧占位 (给 WebView 留位置)
                        Spacer().frame(width: NotchConfig.VRM.headSize.width + 12)
                    }
                    .frame(height: NotchConfig.closedSize.height)

                } else {
                    // === [展开状态 UI] ===
                    HStack(alignment: .top, spacing: 0) {
                        // [左侧] SwiftUI 交互区
                        VStack(alignment: .leading, spacing: 12) {
                            // Header
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

                            // Chat Content
                            ScrollView {
                                Text(vm.chatContent)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer()

                            // Bottom Actions
                            HStack {
                                Button(action: { print("Mic Tapped") }) {
                                    Label("Chat", systemImage: "mic.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.indigo)
                                .controlSize(.small)
                            }
                        }
                        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // [右侧] 给 WebView 留白
                        Spacer().frame(width: NotchConfig.VRM.bodyWidth)
                    }
                    .padding(.top, NotchConfig.closedSize.height) // 让出顶部物理刘海高度
                }

                // 4. WebView 层 (始终浮在最上层，通过布局参数调整位置)
                VRMWebView(state: vm.state)
                    .frame(
                        width: vm.state == .closed ? NotchConfig.VRM.headSize.width : NotchConfig.VRM.bodyWidth,
                        height: vm.state == .closed ? NotchConfig.VRM.headSize.height : (NotchConfig.openSize.height - NotchConfig.closedSize.height)
                    )
                    .mask(RoundedRectangle(cornerRadius: vm.state == .closed ? NotchConfig.VRM.headCornerRadius : NotchConfig.VRM.bodyCornerRadius))
                    // 动态定位：折叠时居中/置顶，展开时位于刘海下方
                    .padding(.top, vm.state == .closed ? (NotchConfig.closedSize.height - NotchConfig.VRM.headSize.height) / 2 : NotchConfig.closedSize.height)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: vm.currentSize.width, height: vm.currentSize.height, alignment: .top)
            .contentShape(Rectangle()) // 确保透明区域也能响应 Hover
            .onHover { hovering in
                if hovering { vm.hoverStarted() }
                else { vm.hoverEnded() }
            }
        }
        // [关键修复] 锁定外层 Frame 为窗口最大尺寸，并顶部对齐
        .frame(width: NotchConfig.windowSize.width, height: NotchConfig.windowSize.height, alignment: .top)
        .ignoresSafeArea()
    }
}
