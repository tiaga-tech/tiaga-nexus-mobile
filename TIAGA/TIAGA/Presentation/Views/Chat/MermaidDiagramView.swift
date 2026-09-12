//
//  MermaidDiagramView.swift
//  TIAGA
//

import SwiftUI

/// Renders a Mermaid `graph TD` source string as an SVG diagram.
///
/// The real web client renders Mermaid via `DiagramBlock` + mermaid.js and
/// supports pan/zoom when interactive. This mirror uses the same vendored
/// mermaid build, loaded from the app bundle only, and implements pan/zoom in
/// JavaScript so both axes move together and the rendered SVG stays clamped to
/// the viewport.
struct MermaidDiagramView: View {
    let source: String
    var isInteractive = false

    private static let template = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
      <style>
        html, body { margin: 0; padding: 0; height: 100%; background: transparent; }
        #stage {
          position: relative;
          width: 100%;
          height: 100%;
          overflow: hidden;
          touch-action: none;
        }
        #diagram {
          position: absolute;
          inset: 0;
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0;
          padding: 8px;
          transform-origin: center center;
        }
        svg { max-width: 100%; height: auto; }
      </style>
    </head>
    <body>
      <div id="stage">
        <pre id="diagram" class="mermaid">__SOURCE__</pre>
      </div>
      <script type="text/javascript" src="mermaid.min.js"></script>
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

        const MIN_ZOOM = 0.25;
        const MAX_ZOOM = 4;
        const stage = document.getElementById('stage');
        const diagram = document.getElementById('diagram');
        let zoom = 1;
        let pan = { x: 0, y: 0 };
        // Keyed by pointerId so one- and two-finger touch gestures can be
        // told apart. Deltas are computed from these tracked positions, not
        // event.movementX/Y — WKWebView does not reliably populate movement
        // deltas for touch-originated Pointer Events, only for mouse.
        const activePointers = new Map();
        let panStart = null;
        let pinchStart = null;

        function pointerMidpoint() {
          const pts = Array.from(activePointers.values());
          return { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
        }

        function pointerDistance() {
          const pts = Array.from(activePointers.values());
          return Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
        }

        function renderState() {
          const rendered = diagram.querySelector('svg');
          const stageRect = stage.getBoundingClientRect();
          let contentW = rendered ? rendered.getBoundingClientRect().width : stageRect.width;
          let contentH = rendered ? rendered.getBoundingClientRect().height : stageRect.height;
          const scaledW = contentW * zoom;
          const scaledH = contentH * zoom;
          const slackX = Math.max(0, scaledW - stageRect.width);
          const slackY = Math.max(0, scaledH - stageRect.height);
          pan.x = Math.min(slackX / 2, Math.max(-slackX / 2, pan.x));
          pan.y = Math.min(slackY / 2, Math.max(-slackY / 2, pan.y));
          diagram.style.transform = `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`;
        }

        function zoomAt(factor, centerX, centerY) {
          const oldZoom = zoom;
          zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom * factor));
          const rect = stage.getBoundingClientRect();
          const stageCenterX = rect.left + rect.width / 2;
          const stageCenterY = rect.top + rect.height / 2;
          const dx = (centerX - stageCenterX) / oldZoom;
          const dy = (centerY - stageCenterY) / oldZoom;
          pan.x -= dx * (zoom - oldZoom);
          pan.y -= dy * (zoom - oldZoom);
          renderState();
        }

        stage.addEventListener('pointerdown', function (event) {
          if (!stage.classList.contains('interactive')) return;
          event.preventDefault();
          stage.setPointerCapture(event.pointerId);
          activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY });

          if (activePointers.size === 1) {
            const [pt] = activePointers.values();
            panStart = { x: pt.x, y: pt.y };
            pinchStart = null;
          } else if (activePointers.size === 2) {
            pinchStart = { distance: pointerDistance(), midpoint: pointerMidpoint() };
            panStart = null;
          }
        });

        stage.addEventListener('pointermove', function (event) {
          if (!activePointers.has(event.pointerId)) return;
          event.preventDefault();
          activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY });

          if (activePointers.size === 1 && panStart) {
            const [pt] = activePointers.values();
            pan.x += pt.x - panStart.x;
            pan.y += pt.y - panStart.y;
            panStart = { x: pt.x, y: pt.y };
            renderState();
          } else if (activePointers.size === 2 && pinchStart) {
            const distance = pointerDistance();
            const midpoint = pointerMidpoint();
            zoomAt(distance / pinchStart.distance, midpoint.x, midpoint.y);
            pinchStart = { distance: distance, midpoint: midpoint };
          }
        });

        function releasePointer(event) {
          activePointers.delete(event.pointerId);
          if (activePointers.size === 1) {
            const [pt] = activePointers.values();
            panStart = { x: pt.x, y: pt.y };
            pinchStart = null;
          } else {
            panStart = null;
            pinchStart = null;
          }
        }

        stage.addEventListener('pointerup', releasePointer);
        stage.addEventListener('pointercancel', releasePointer);

        stage.addEventListener('wheel', function (event) {
          if (!stage.classList.contains('interactive')) return;
          event.preventDefault();
          zoomAt(event.deltaY < 0 ? 1.12 : 1 / 1.12, event.clientX, event.clientY);
        });

        // Re-clamp whenever the Mermaid SVG finishes rendering.
        const observer = new MutationObserver(renderState);
        observer.observe(diagram, { childList: true, subtree: true });
        window.addEventListener('resize', renderState);
        renderState();
      </script>
    </body>
    </html>
    """

    var body: some View {
        let escaped = source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let html = Self.template.replacingOccurrences(of: "__SOURCE__", with: escaped)
        let interactiveHTML = isInteractive
            ? html.replacingOccurrences(of: "<div id=\"stage\">", with: "<div id=\"stage\" class=\"interactive\">")
            : html

        // Pan and pinch-zoom are both implemented in the page's own JS via
        // Pointer Events (see the template above) — the native WKWebView
        // scroll/zoom machinery stays off so it can't compete with them for
        // the same touches.
        VendoredWebView(html: interactiveHTML, isScrollEnabled: false)
            .frame(minHeight: 220)
    }
}
