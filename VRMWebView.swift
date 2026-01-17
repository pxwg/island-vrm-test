import SwiftUI
import WebKit

// 全局单例 WebView，保证生命周期独立于 SwiftUI View
class SharedWebViewHelper: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = SharedWebViewHelper()
    let webView: WKWebView
    override init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        // 【关键】开启开发者工具，允许右键检查元素
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        var resourceBundle: Bundle {
            #if SWIFT_PACKAGE
                return Bundle.module
            #else
                return Bundle.main
            #endif
        }

        if
            let url = resourceBundle.url(forResource: "index", withExtension: "html", subdirectory: "WebResources")
        {
            let dir = url.deletingLastPathComponent()
            print("📂 Loading HTML from: \(url.path)")
            webView.loadFileURL(url, allowingReadAccessTo: dir)
        } else {
            print("❌ Error: index.html not found in WebResources")
        }
    }

    // 调用 JS 切换模式
    func setMode(_ mode: String) {
        let js = "window.setCameraMode('\(mode)')"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

struct VRMWebView: NSViewRepresentable {
    // 绑定当前状态
    var state: NotchViewModel.State

    func makeNSView(context _: Context) -> WKWebView {
        return SharedWebViewHelper.shared.webView
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
        // 1. 根据 Swift 状态调用 JS 动画
        let mode = (state == .closed) ? "head" : "body"
        SharedWebViewHelper.shared.setMode(mode)

        // 2. 通知 Web 端调整 Canvas 大小 (解决 SwiftUI 动画期间的拉伸问题)
        // 注意：SwiftUI layout 变化频繁，这里可能需要防抖，MVP 先直接调
        DispatchQueue.main.async {
            let size = nsView.frame.size
            if size.width > 0, size.height > 0 {
                let js = "if(window.updateSize) window.updateSize(\(size.width), \(size.height))"
                nsView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
}
