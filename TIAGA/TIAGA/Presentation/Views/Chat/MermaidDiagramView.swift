//
//  MermaidDiagramView.swift
//  TIAGA
//

import SwiftUI

/// Renders a Mermaid `graph TD` source string as an SVG diagram.
///
/// The real web client renders Mermaid via `DiagramBlock` + mermaid.js.
/// This mirror uses the same vendored mermaid build, but it is loaded from
/// the app bundle only — there is no CDN or runtime network dependency.
/// The result is a dark themed, self-contained page rendered by `WKWebView`.
struct MermaidDiagramView: View {
    let source: String

    private static let template = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        html, body { margin: 0; padding: 0; background: transparent; }
        #diagram { padding: 8px; }
        svg { max-width: 100%; height: auto; }
      </style>
    </head>
    <body>
      <pre id="diagram" class="mermaid">__SOURCE__</pre>
      <script type="text/javascript">
        mermaid.initialize({
          startOnLoad: true,
          securityLevel: 'loose',
          theme: 'dark',
          themeVariables: {
            darkMode: true,
            background: 'rgba(255,255,255,0.04)',
            primaryColor: 'rgba(59,130,246,0.22)',
            primaryTextColor: '#e5e7eb',
            primaryBorderColor: 'rgba(59,130,246,0.75)',
            lineColor: 'rgba(148,163,184,0.65)',
            secondaryColor: 'rgba(255,255,255,0.06)',
            tertiaryColor: 'rgba(5,7,13,0.55)',
            fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace'
          }
        });
      </script>
      <script type="text/javascript" src="mermaid.min.js"></script>
    </body>
    </html>
    """

    var body: some View {
        let escaped = source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        VendoredWebView(html: Self.template.replacingOccurrences(of: "__SOURCE__", with: escaped))
            .frame(minHeight: 220)
    }
}
