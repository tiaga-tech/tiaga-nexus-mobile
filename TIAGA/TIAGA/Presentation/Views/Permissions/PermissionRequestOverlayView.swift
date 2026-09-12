//
//  PermissionRequestOverlayView.swift
//  TIAGA
//

import SwiftUI

/// The app-wide approval prompt for a pending `PermissionRequest`. Wired
/// into `FleetConsoleRootView` so it renders above whatever screen the
/// operator is on, regardless of route.
///
/// No dismiss gesture of any kind — no scrim tap, no swipe, no close button
/// — matching the real backend exactly: `PermissionManager.cs` blocks the
/// gated call indefinitely with a "non-dismissable" overlay, so Approve/Deny
/// are the only way out. The content stays in the view hierarchy at all
/// times and is hidden via opacity, not conditional insertion — the same
/// lesson from the side menu drawer: conditionally inserting/removing custom
/// glass content doesn't reliably animate on removal.
struct PermissionRequestOverlayView: View {
    @ObservedObject var viewModel: PermissionRequestOverlayViewModel
    @State private var displayedRequest: PermissionRequest?

    private var isPresented: Bool { viewModel.currentRequest != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(isPresented ? 0.6 : 0)
                .ignoresSafeArea()

            if let request = displayedRequest {
                card(for: request)
                    .opacity(isPresented ? 1 : 0)
                    .padding(TIAGASpacing.xl)
            }
        }
        .allowsHitTesting(isPresented)
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        .onChange(of: viewModel.currentRequest) { _, newValue in
            // Keep the last non-nil request around after it resolves, so the
            // fade-out has content to fade rather than popping to blank.
            if let newValue {
                displayedRequest = newValue
            }
        }
    }

    /// "{requester} on {deviceName} {kind label}" — e.g. "Pip on Mac wants
    /// to edit a file" — matching `PermissionOverlay.tsx`'s exact structure
    /// and wording (`KIND_LABEL`), not `request.tool`'s raw identifier
    /// ("edit", "write", "bash", ...) substituted into a fixed "wants to
    /// run X on Y" template: the tool name isn't a verb, so that read as
    /// nonsense ("wants to run edit on Mac") for anything but `.command`.
    private func titleLine(for request: PermissionRequest) -> Text {
        Text(request.requester)
            .font(TIAGATypography.subheadlineEmphasis)
            .foregroundStyle(TIAGAColor.textPrimary)
        + Text(" on ")
        + Text(request.deviceName)
            .font(TIAGATypography.subheadlineEmphasis)
            .foregroundStyle(TIAGAColor.textPrimary)
        + Text(" \(Self.kindLabel(for: request.kind))")
    }

    /// Matches `PermissionOverlay.tsx`'s `KIND_LABEL` exactly (minus
    /// `mcp`, which has no domain concept in this app — see Section 8's
    /// notes on MCP being out of scope).
    private static func kindLabel(for kind: PermissionRequestKind) -> String {
        switch kind {
        case .command: return "wants to run a command"
        case .write: return "wants to write a file"
        case .edit: return "wants to edit a file"
        }
    }

    private func card(for request: PermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.md) {
            VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                Text("Permission needed")
                    .font(TIAGATypography.headline)
                    .foregroundStyle(TIAGAColor.statusWarning)
                titleLine(for: request)
                    .font(TIAGATypography.subheadline)
                    .foregroundStyle(TIAGAColor.textSecondary)
            }

            detailSection(for: request)
                .frame(maxWidth: .infinity, maxHeight: 260, alignment: .leading)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
            }

            HStack(spacing: TIAGASpacing.md) {
                Button("Deny", role: .destructive) {
                    Task { await viewModel.deny() }
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                Button("Approve") {
                    Task { await viewModel.approve() }
                }
                .buttonStyle(.glassProminent)
                .tint(TIAGAColor.brandAccent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(TIAGASpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous)
                .strokeBorder(TIAGAColor.border, lineWidth: 1)
        )
    }

    /// `.edit` renders per-file tabs + a file-path label + line-level diffs
    /// (see `PermissionEditFilesView`) from `files`, matching the web
    /// client's `EditReview`/`FileLabel` — not the backend's flattened
    /// `detail` string, which only prefixes the first line of a multi-line
    /// change (a quirk of `PermissionManager.cs`'s own string
    /// concatenation, not what the web client's interactive overlay
    /// actually renders). `.command` is a shell invocation; `.write`'s
    /// `detail` is a full new file's content, best highlighted by its
    /// extension since the tool itself carries no explicit language.
    @ViewBuilder
    private func detailSection(for request: PermissionRequest) -> some View {
        if request.kind == .edit, let files = request.files, !files.isEmpty {
            PermissionEditFilesView(files: files)
                .id(request.id)
        } else {
            let (code, language) = fallbackDetailContent(for: request)
            HighlightedCodeView(code: code, language: language, isScrollable: true)
                .background(TIAGAColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
        }
    }

    private func fallbackDetailContent(for request: PermissionRequest) -> (code: String, language: String) {
        switch request.kind {
        case .command:
            return (request.detail, "bash")
        case .write:
            return (request.detail, Self.language(forFileExtension: request.file))
        case .edit:
            return (request.detail, "diff")
        }
    }

    private static func language(forFileExtension path: String?) -> String {
        let ext = path.flatMap { $0.split(separator: ".").last }.map { $0.lowercased() }
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        case "md": return "markdown"
        case "html", "xml": return "xml"
        case "scss": return "scss"
        case "css": return "css"
        case "sh", "bash": return "bash"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "java": return "java"
        case "c", "h": return "c"
        case "cpp", "cc", "hpp": return "cpp"
        case "cs": return "csharp"
        case "sql": return "sql"
        default: return "plaintext"
        }
    }
}

#Preview {
    ZStack {
        TIAGAColor.background.ignoresSafeArea()
        PermissionRequestOverlayView(viewModel: PermissionRequestOverlayViewModel())
    }
}
