import SwiftUI
import WebKit

class SharedWebViewHelper: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = SharedWebViewHelper()
    let webView: WKWebView
    private var mouseTrackingTimer: Timer?

    override init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: .zero, configuration: config)
        // 关键：允许背景透明
        webView.setValue(false, forKey: "drawsBackground")

        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self

        #if DEBUG_SERVER
            if let url = URL(string: "http://127.0.0.1:5500") {
                webView.load(URLRequest(url: url))
            }
        #else
            // [修复] 移除错误的 bundle 查找逻辑，直接使用 Bundle.main
            // build.sh 将 WebResources 直接拷贝到了 App Bundle 的 Resources 根目录下
            if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebResources") {
                // QKWebView 需要读取同级目录下的 .vrm 和 .vrma 文件，需要允许读取 WebResources 目录
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                print("❌ Error: Could not find WebResources/index.html in Main Bundle")
            }
        #endif

        startMouseTracking()
    }

    // [新增] WKNavigationDelegate 方法：页面加载完成后注入配置
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        injectCameraConfig()
    }

    func setMode(_ mode: String) {
        webView.evaluateJavaScript("window.setCameraMode('\(mode)')", completionHandler: nil)
    }

    // [新增] 发送演绎指令
    func triggerPerformance(_ perf: Performance) {
        do {
            let data = try JSONEncoder().encode(perf)
            if let jsonString = String(data: data, encoding: .utf8) {
                let js = "if(window.triggerPerformance) window.triggerPerformance(\(jsonString))"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        } catch {
            print("Failed to encode performance: \(error)")
        }
    }

    // [新增] 发送状态指令
    func setAgentState(_ state: String) {
        let js = "if(window.setAgentState) window.setAgentState('\(state)')"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // [新增] 实时更新相机配置
    func updateCameraConfig() {
        if let jsonString = CameraSettings.shared.toJSON() {
            let js = "if(window.updateCameraConfig) window.updateCameraConfig(\(jsonString))"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // [新增] 初始化时注入相机配置
    func injectCameraConfig() {
        if let jsonString = CameraSettings.shared.toJSON() {
            let js = "if(window.setCameraConfig) window.setCameraConfig(\(jsonString)); else window.__pendingCameraConfig = \(jsonString);"
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("⚠️ Failed to inject camera config: \(error)")
                } else {
                    print("✅ Camera config injected successfully")
                }
            }
        }
    }

    // --- 鼠标追踪逻辑 ---
    private func startMouseTracking() {
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.sendMousePosition()
        }
    }

    private func sendMousePosition() {
        let mouseLoc = NSEvent.mouseLocation
        guard let window = NSApplication.shared.windows.first(where: { $0 is NotchWindow }) else { return }

        let centerX = window.frame.midX
        let centerY = window.frame.midY

        let dx = mouseLoc.x - centerX
        let dy = mouseLoc.y - centerY

        if webView.window != nil {
            let js = "if(window.updateMouseParams) window.updateMouseParams(\(dx), \(dy))"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

struct VRMWebView: NSViewRepresentable {
    var state: NotchViewModel.State

    func makeNSView(context _: Context) -> NSView {
        // [新增] 极为关键：判断是否在预览模式
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            let mockView = NSView()
            mockView.wantsLayer = true
            mockView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
            return mockView
        }
        return SharedWebViewHelper.shared.webView
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        // [新增] 只有是 WKWebView 才执行逻辑，防止崩溃
        if let _ = nsView as? WKWebView {
            SharedWebViewHelper.shared.setMode(state == .closed ? "head" : "body")
        }
    }
}
