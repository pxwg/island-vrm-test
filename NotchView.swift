import SwiftUI

struct NotchView: View {
    @StateObject var vm = NotchViewModel()
    @Namespace private var animation

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .center, spacing: 0) {
                ZStack(alignment: .top) {
                    // --- 背景层 ---
                    NotchShape(
                        topCornerRadius: vm.currentTopRadius,
                        bottomCornerRadius: vm.currentBottomRadius
                    )
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)

                    // --- 内容层 ---
                    if vm.state == .closed {
                        // === [折叠状态] ===
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .opacity(0.8)
                                .padding(.trailing, 4)

                            VRMWebView(state: .closed)
                                .frame(width: 40, height: 40)
                                .matchedGeometryEffect(id: "vrm-canvas", in: animation)
                                .mask(Circle())
                        }
                        .padding(.trailing, 12)
                        .frame(width: vm.currentSize.width, height: vm.currentSize.height)

                    } else {
                        // === [展开状态] ===
                        ZStack(alignment: .top) {
                            // 顶部占位 (避开物理刘海)
                            Spacer().frame(height: NotchConfig.closedSize.height)

                            HStack(alignment: .top, spacing: 0) {
                                // [左侧] 控制面板 (新增按钮样例)
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("VRM Interactive")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)

                                        Text("Status: Online")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .transition(.opacity.animation(.easeIn.delay(0.1)))

                                    Spacer()

                                    HStack(spacing: 12) {
                                        Button(action: { print("💬 Chat Clicked") }) {
                                            Label("Chat", systemImage: "message.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.indigo)
                                        .controlSize(.small)

                                        Button(action: { print("🎤 Mic Clicked") }) {
                                            Image(systemName: "mic.fill")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.white.opacity(0.2))
                                        .controlSize(.small)

                                        Button(action: { print("⚙️ Settings Clicked") }) {
                                            Image(systemName: "ellipsis")
                                        }
                                        .buttonStyle(.plain) // 纯图标样式
                                        .foregroundColor(.gray)
                                        .controlSize(.small)
                                    }
                                    .padding(.bottom, 14)
                                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeOut.delay(0.15)))
                                }
                                .padding(.leading, 24)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // [右侧] VRM 全身渲染
                                VStack {
                                    VRMWebView(state: .expanded)
                                        .frame(width: 140, height: 180)
                                        .matchedGeometryEffect(id: "vrm-canvas", in: animation)
                                        .mask(RoundedRectangle(cornerRadius: 12))
                                }
                                .frame(width: 150)
                                .padding(.trailing, 10)
                                .padding(.bottom, 0)
                            }
                            .frame(width: vm.currentSize.width)
                        }
                    }
                }
                // 形状与交互定义
                .clipShape(NotchShape(
                    topCornerRadius: vm.currentTopRadius,
                    bottomCornerRadius: vm.currentBottomRadius
                ))
                .frame(width: vm.currentSize.width, height: vm.currentSize.height, alignment: .top)
                .contentShape(Rectangle())
                .onHover { isHovering in
                    if isHovering { vm.hoverStarted() }
                    else { vm.hoverEnded() }
                }
                .onTapGesture {
                    print("Background Tapped")
                }

                // 展开时的下方占位 (保持透明)
                if vm.state == .expanded {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        // 关键：限制外层尺寸且不加背景
        .frame(maxWidth: NotchConfig.windowSize.width, maxHeight: NotchConfig.windowSize.height, alignment: .top)
    }
}
