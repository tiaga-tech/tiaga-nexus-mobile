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

    private func card(for request: PermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.md) {
            VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                Text(request.requester)
                    .font(TIAGATypography.headline)
                    .foregroundStyle(TIAGAColor.textPrimary)
                Text("wants to run \(request.tool) on \(request.deviceName)")
                    .font(TIAGATypography.subheadline)
                    .foregroundStyle(TIAGAColor.textSecondary)
            }

            ScrollView {
                Text(request.detail)
                    .font(TIAGATypography.command)
                    .foregroundStyle(TIAGAColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(TIAGASpacing.sm)
            .background(TIAGAColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))

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
}

#Preview {
    ZStack {
        TIAGAColor.background.ignoresSafeArea()
        PermissionRequestOverlayView(viewModel: PermissionRequestOverlayViewModel())
    }
}
