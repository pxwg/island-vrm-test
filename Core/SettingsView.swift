import SwiftUI

// [修改] 标记为 public
public struct SettingsView: View {
    @ObservedObject var settings = CameraSettings.shared
    @State private var selectedTab: SettingsTab = .head

    public var onBodyModeSelected: ((Bool) -> Void)?

    public init(onBodyModeSelected: ((Bool) -> Void)? = nil) {
        self.onBodyModeSelected = onBodyModeSelected
    }

    enum SettingsTab: String, CaseIterable {
        case head = "Head Mode"
        case body = "Body Mode"
        // case about = "About"
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            CameraModeSettingsView(
                mode: "Head",
                setting: $settings.config.head,
                // [修改] onSave 只负责由于重置等操作引起的保存，不再负责实时 Slider 的保存
                onSave: { settings.save() }
            )
            .tabItem { Label("Head Mode", systemImage: "person.crop.circle") }
            .tag(SettingsTab.head)

            CameraModeSettingsView(
                mode: "Body",
                setting: $settings.config.body,
                onSave: { settings.save() }
            )
            .tabItem { Label("Body Mode", systemImage: "figure.stand") }
            .tag(SettingsTab.body)
        }
        .frame(width: 600, height: 450)
        .onChange(of: selectedTab) { _, newValue in
            onBodyModeSelected?(newValue == .body)
        }
        .onAppear {
            if selectedTab == .body { onBodyModeSelected?(true) }
        }
        .onDisappear {
            onBodyModeSelected?(false)
        }
    }
}

// MARK: - Camera Mode Settings View

struct CameraModeSettingsView: View {
    let mode: String
    @Binding var setting: CameraSetting
    let onSave: () -> Void

    // 用于防抖保存到 UserDefaults
    @State private var saveTimer: Timer?

    var body: some View {
        Form {
            Section("Camera Position") {
                SliderRow(label: "X", value: $setting.position.x, range: -5 ... 5, onChange: handleLiveChange)
                SliderRow(label: "Y", value: $setting.position.y, range: -5 ... 5, onChange: handleLiveChange)
                SliderRow(label: "Z", value: $setting.position.z, range: -5 ... 5, onChange: handleLiveChange)
            }

            Section("Look At Target") {
                SliderRow(label: "X", value: $setting.target.x, range: -5 ... 5, onChange: handleLiveChange)
                SliderRow(label: "Y", value: $setting.target.y, range: -5 ... 5, onChange: handleLiveChange)
                SliderRow(label: "Z", value: $setting.target.z, range: -5 ... 5, onChange: handleLiveChange)
            }

            Section("Field of View") {
                SliderRow(label: "FOV", value: $setting.fov, range: 10 ... 120, step: 1, format: "%.0f°", onChange: handleLiveChange)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        CameraSettings.shared.reset()
                        // 重置时需要手动触发一次全量更新
                        SharedWebViewHelper.shared.updateCameraConfig()
                        onSave()
                    }
                    .foregroundColor(.red)

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    // [核心优化] 实时处理逻辑
    private func handleLiveChange() {
        // 1. 立即：发送给 WebView，实现 0 延迟预览
        SharedWebViewHelper.shared.updateCameraConfig()

        // 2. 延迟：保存到硬盘 (UserDefaults)，避免频繁写入导致卡顿
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            print("💾 Auto-saving settings to disk...")
            onSave() // 这里只调用保存
        }
    }
}

// [新增] 提取 Slider 组件，减少重复代码，保证逻辑统一
struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    var format: String = "%.3f"
    var onChange: () -> Void

    var body: some View {
        HStack {
            Text("\(label):")
                .frame(width: 35, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)

            // [修复] 这里之前的 qh 改回了正确的 in
            Slider(value: $value, in: range)
                .onChange(of: value) { _, _ in
                    onChange()
                }

            Text(String(format: format, value))
                .frame(width: 55, alignment: .trailing)
                .monospacedDigit()
                .font(.caption)
        }
    }
}
