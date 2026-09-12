//
//  HighlightedCodeView.swift
//  TIAGA
//

import SwiftUI

/// Renders a code card with syntax highlighting.
///
/// Uses the vendored highlight.js bundle plus the vendored `github-dark.css`
/// theme (both loaded from the app bundle, never the network). The web view is
/// non-scrolling so the card grows with its content; the surrounding dark glass
/// card provides the chrome and language label.
struct HighlightedCodeView: View {
    let code: String
    let language: String
    var isScrollable = false

    private static let template = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link rel="stylesheet" href="github-dark.css">
      <style>
        html, body {
          margin: 0;
          padding: 0;
          background: rgba(0,0,0,0.5);
          color: #e5e7eb;
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 13px;
          line-height: 1.55;
        }
        pre { margin: 0; padding: 12px; white-space: pre; overflow: auto; }
        code.hljs { background: transparent !important; padding: 0 !important; }
      </style>
    </head>
    <body>
      <pre><code class="language-__LANGUAGE__">__CODE__</code></pre>
      <script type="text/javascript" src="highlight.min.js"></script>
      <script type="text/javascript">
        document.addEventListener('DOMContentLoaded', function () {
          hljs.highlightAll();
        });
      </script>
    </body>
    </html>
    """

    var body: some View {
        let escapedCode = code
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let safeLanguage = language.isEmpty ? "plaintext" : language
        let html = Self.template
            .replacingOccurrences(of: "__LANGUAGE__", with: safeLanguage)
            .replacingOccurrences(of: "__CODE__", with: escapedCode)

        VendoredWebView(html: html, isScrollEnabled: isScrollable)
            .frame(minHeight: 90)
    }
}
