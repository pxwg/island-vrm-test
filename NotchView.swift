import SwiftUI

struct NotchView: View {
    @StateObject var vm = NotchViewModel()
    @Namespace private var animation

    var body: some View {
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

                        // 呼吸灯
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .opacity(0.8)
                            .padding(.trailing, 4)

                        // --- VRM 头部渲染 ---
                        // 使用 .id 保持视图身份，防止重建
                        VRMWebView(state: .closed)
                            .frame(width: 40, height: 40) // 稍微大一点，看清头部
                            .matchedGeometryEffect(id: "vrm-canvas", in: animation)
                            // 稍微裁剪一下边缘，使其融入
                            .mask(Circle())
                    }
                    .padding(.trailing, 12)
                    .frame(width: vm.currentSize.width, height: vm.currentSize.height)

                } else {
                    // === [展开状态] ===
                    ZStack(alignment: .top) {
                        Spacer().frame(height: NotchConfig.closedSize.height)

                        HStack(alignment: .top, spacing: 0) {
                            // [左侧] 控制面板 (不变)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("VRM Interactive")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(.opacity.animation(.easeIn.delay(0.1)))

                                Text("Status: Online")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .transition(.opacity.animation(.easeIn.delay(0.2)))

                                Spacer()
                                // ... 按钮代码同上 ...
                            }
                            .padding(.leading, 30)
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // [右侧] VRM 全身渲染
                            VStack {
                                VRMWebView(state: .expanded)
                                    .frame(width: 140, height: 180) // 展开尺寸
                                    .matchedGeometryEffect(id: "vrm-canvas", in: animation)
                                    // 展开时不遮罩，或者用圆角矩形遮罩
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
            .clipShape(NotchShape(
                topCornerRadius: vm.currentTopRadius,
                bottomCornerRadius: vm.currentBottomRadius
            ))
            .frame(width: vm.currentSize.width, height: vm.currentSize.height, alignment: .top)
            // --- 交互感应 ---
            .contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering { vm.hoverStarted() }
                else { vm.hoverEnded() }
            }

            Spacer()
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }
}

#if DEBUG
    #Preview {
        // 设置一个合适的预览背景和大小，模拟刘海屏环境
        NotchView()
            .frame(width: 800, height: 400)
            .background(Color.gray.opacity(0.3))
    }
#endif
