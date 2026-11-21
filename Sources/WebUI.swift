import AppKit
import Foundation
import WebKit

@MainActor
protocol WebUIBridgeDelegate: AnyObject {
    func webUIDidBecomeReady()
    func webUIRequestedRefresh()
    func webUISelectedRange(_ range: String)
    func webUISelectedConversation(_ value: String)
    func webUIUpdatedSettings(_ patch: [String: Any])
    func webUIResetSettings()
}

/// Strictly offline WKWebView host:
/// - Uses nonPersistent data store (writes zero cookies/cache to disk).
/// - Blocks every external or file navigation via WKNavigationDelegate.
/// - Communicates strictly in-memory via WKScriptMessageHandler + Base64 JSON push.
@MainActor
final class OfflineWebUIController: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    weak var delegate: WebUIBridgeDelegate?
    private var isReady = false
    private var pendingPush: (base64: String, darkMode: Bool)?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let ucc = WKUserContentController()
        config.userContentController = ucc

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.allowsMagnification = false
        wv.allowsBackForwardNavigationGestures = false
        self.webView = wv

        super.init()

        ucc.add(self, name: "gravihud")
        wv.navigationDelegate = self
        loadLocalHTML()
    }

    private func loadLocalHTML() {
        let html: String
        if let url = Bundle.main.url(forResource: "panel", withExtension: "html"),
           let loaded = try? String(contentsOf: url, encoding: .utf8) {
            html = loaded
        } else {
            html = """
            <!DOCTYPE html><html><body style="font-family:-apple-system;padding:16px;">
            <p>Missing Resources/panel.html</p></body></html>
            """
        }
        webView.loadHTMLString(html, baseURL: nil)
    }

    func pushTelemetry(_ payload: TelemetryPayload, darkMode: Bool) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else { return }
        let b64 = data.base64EncodedString()
        if !isReady {
            pendingPush = (b64, darkMode)
            return
        }
        deliver(base64: b64, darkMode: darkMode)
    }

    func pushTheme(darkMode: Bool) {
        guard isReady else { return }
        let flag = darkMode ? "true" : "false"
        webView.evaluateJavaScript("window.__gravihudSetTheme && window.__gravihudSetTheme(\(flag));", completionHandler: nil)
    }

    private func deliver(base64: String, darkMode: Bool) {
        let flag = darkMode ? "true" : "false"
        webView.evaluateJavaScript("window.__gravihudReceiveBase64 && window.__gravihudReceiveBase64('\(base64)', \(flag));", completionHandler: nil)
    }

    // MARK: - WKNavigationDelegate (Zero-Network Enforcement)

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .other,
           navigationAction.request.url?.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "gravihud",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else { return }

        switch type {
        case "ready":
            isReady = true
            if let pending = pendingPush {
                pendingPush = nil
                deliver(base64: pending.base64, darkMode: pending.darkMode)
            }
            delegate?.webUIDidBecomeReady()
        case "refresh":
            delegate?.webUIRequestedRefresh()
        case "setRange":
            if let range = body["range"] as? String {
                delegate?.webUISelectedRange(range)
            }
        case "selectConv":
            if let cid = body["conversationId"] as? String {
                delegate?.webUISelectedConversation(cid)
            }
        case "updateSettings":
            if let patch = body["patch"] as? [String: Any] {
                delegate?.webUIUpdatedSettings(patch)
            }
        case "resetSettings":
            delegate?.webUIResetSettings()
        default:
            break
        }
    }
}
