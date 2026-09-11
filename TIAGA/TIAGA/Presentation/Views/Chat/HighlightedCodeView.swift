//
//  HighlightedCodeView.swift
//  TIAGA
//

import SwiftUI

/// Renders a code card with syntax highlighting.
///
/// Uses the vendored highlight.js bundle (loaded from the app bundle, never
/// the network) and a dark theme tuned to the TIAGA palette. The web view is
/// non-scrolling so the card grows with its content, keeping the surrounding
/// dark glass card chrome intact.
struct HighlightedCodeView: View {
    let code: String
    let language: String

    private static let template = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        html, body {
          margin: 0;
          padding: 0;
          background: rgba(255,255,255,0.04);
          color: #e5e7eb;
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 13px;
          line-height: 1.5;
        }
        pre { margin: 0; padding: 12px; white-space: pre-wrap; }
        code.hljs { background: transparent; padding: 0; }
        .hljs-keyword, .hljs-selector-tag, .hljs-literal, .hljs-section, .hljs-link { color: #60a5fa; }
        .hljs-string, .hljs-attr, .hljs-template-tag, .hljs-template-variable { color: #34d399; }
        .hljs-comment, .hljs-quote { color: #64748b; font-style: italic; }
        .hljs-number, .hljs-symbol, .hljs-bullet { color: #fbbf24; }
        .hljs-type, .hljs-title, .hljs-title.class_, .hljs-title.function_ { color: #c084fc; }
        .hljs-variable, .hljs-name, .hljs-attribute, .hljs-tag { color: #93c5fd; }
        .hljs-built_in, .hljs-builtin-name, .hljs-meta { color: #f472b6; }
      </style>
    </head>
    <body>
      <pre><code class="language-__LANGUAGE__">__CODE__</code></pre>
      <script type="text/javascript" src="highlight.min.js"></script>
      <script type="text/javascript">
        hljs.highlightAll();
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

        VendoredWebView(html: html)
            .frame(minHeight: 90)
    }
}
