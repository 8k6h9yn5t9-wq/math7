import SwiftUI
import WebKit

/// Shows the problem, choices, feedback and worked steps. The problem bank writes HTML
/// (stacked fractions, number lines, tables), so we draw it with the same styles as the web app.
struct QuestionWebView: UIViewRepresentable {
    /// JSON-ready state for render() in question.html.
    var state: [String: Any]
    @Binding var height: CGFloat
    var onChoice: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let proxy = WeakHandler(context.coordinator)
        for name in ["height", "choice", "ready"] { config.userContentController.add(proxy, name: name) }
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        if let url = Bundle.main.url(forResource: "question", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        context.coordinator.web = web
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.push(state)
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        for name in ["height", "choice", "ready"] { web.configuration.userContentController.removeScriptMessageHandler(forName: name) }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: QuestionWebView
        weak var web: WKWebView?
        private var ready = false
        private var pending: String?
        private var lastSent: String?

        init(_ p: QuestionWebView) { parent = p }

        func push(_ state: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else { return }
            if json == lastSent { return }
            if ready { send(json) } else { pending = json }
        }

        private func send(_ json: String) {
            lastSent = json
            web?.evaluateJavaScript("render(\(json))", completionHandler: nil)
        }

        func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                ready = true
                if let p = pending { pending = nil; send(p) }
            case "height":
                if let h = (message.body as? NSNumber)?.doubleValue, abs(CGFloat(h) - parent.height) > 0.5 {
                    DispatchQueue.main.async { self.parent.height = CGFloat(h) }
                }
            case "choice":
                if let i = (message.body as? NSNumber)?.intValue { parent.onChoice(i) }
            default: break
            }
        }
    }
}

/// WKUserContentController keeps a strong reference to its handlers; this breaks the cycle.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(ucc, didReceive: message)
    }
}
