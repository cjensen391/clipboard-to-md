import Foundation
import WebKit

/// Hosts the vendored Turndown library inside a headless `WKWebView` and
/// converts HTML → Markdown. Turndown needs a real DOM, which bare
/// JavaScriptCore lacks — hence the WebView.
///
/// `@MainActor` because `WKWebView` is main-thread-only.
@MainActor
final class TurndownEngine: NSObject {

    enum EngineError: LocalizedError {
        case notReady
        case badResult
        var errorDescription: String? {
            switch self {
            case .notReady: return "The Markdown converter failed to load."
            case .badResult: return "The Markdown converter returned an unexpected result."
            }
        }
    }

    private let webView: WKWebView
    /// Continuations awaiting the initial page load. Resolved on `didFinish`.
    private var readyContinuations: [CheckedContinuation<Void, Error>] = []
    private var isReady = false
    private var loadError: Error?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        self.webView.navigationDelegate = self
    }

    /// Kick off loading the converter page. Safe to call once at launch so the
    /// first real conversion is instant.
    func warmUp() {
        guard !isReady, loadError == nil else { return }
        do {
            let html = try ResourceLocator.converterHTML()
            // Allow read access to the whole Resources dir so <script src> resolves.
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        } catch {
            loadError = error
            resumeReady(with: error)
        }
    }

    /// Convert an HTML string to Markdown.
    func convert(html: String) async throws -> String {
        try await ensureReady()
        let result = try await webView.callAsyncJavaScript(
            "return window.convertHTMLToMarkdown(html);",
            arguments: ["html": html],
            contentWorld: .page
        )
        guard let markdown = result as? String else {
            throw EngineError.badResult
        }
        return markdown
    }

    /// Await the converter being loaded and ready.
    private func ensureReady() async throws {
        if isReady { return }
        if let loadError { throw loadError }
        warmUp()
        try await withCheckedThrowingContinuation { continuation in
            readyContinuations.append(continuation)
        }
    }

    private func resumeReady(with error: Error?) {
        let continuations = readyContinuations
        readyContinuations.removeAll()
        for continuation in continuations {
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }
}

extension TurndownEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        resumeReady(with: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadError = error
        resumeReady(with: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadError = error
        resumeReady(with: error)
    }
}
