//
//  VendoredWebView.swift
//  TIAGA
//

import SwiftUI
import WebKit

/// Renders a fully self-contained HTML page in a `WKWebView`.
///
/// The page loads only vendored JavaScript from the app bundle — it never
/// makes a runtime network request. This is used for Mermaid diagrams and
/// highlight.js code blocks, matching the real web client's JS rendering
/// paths while keeping the mobile app offline by design.
struct VendoredWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }
}
