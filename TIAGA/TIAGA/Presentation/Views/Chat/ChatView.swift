//
//  ChatView.swift
//  TIAGA
//

import SwiftUI

/// The main orchestrator chat screen: a text-only transcript that interleaves
/// messages and tool-usage events, the shared composer, a reset button, the
/// context-usage bar, and an entry point into the dynamic UI card history.
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showsDynamicUICardBrowser = false
    @State private var showsResetConfirmation = false
    @Environment(\.isSideMenuOpenGestureActive) private var isSideMenuOpenGestureActive

    init() {
        #if DEBUG
        // Screenshot/QA tooling only. `simctl` cannot tap/type, so these
        // overrides let a screenshot pass present the card browser or the
        // reset confirmation directly via SIMCTL_CHILD_ variables. Never
        // present in a Release build.
        let environment = ProcessInfo.processInfo.environment
        _showsDynamicUICardBrowser = State(initialValue: environment["TIAGA_DEBUG_SHOW_DYNAMIC_UI"] == "1")
        _showsResetConfirmation = State(initialValue: environment["TIAGA_DEBUG_SHOW_RESET_CONFIRMATION"] == "1")
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                        if viewModel.transcript.isEmpty {
                            Text("Start a conversation with TIAGA.")
                                .font(TIAGATypography.subheadline)
                                .foregroundStyle(TIAGAColor.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, TIAGASpacing.xl)
                        } else {
                            ForEach(viewModel.transcript) { message in
                                TranscriptRow(message: message)
                            }
                        }

                        if viewModel.isStreaming {
                            HStack(spacing: TIAGASpacing.xs) {
                                ProgressView()
                                    .tint(TIAGAColor.brandAccent)
                                Text("TIAGA is replying…")
                                    .font(TIAGATypography.caption)
                                    .foregroundStyle(TIAGAColor.textTertiary)
                            }
                            .padding(.top, TIAGASpacing.sm)
                        }

                        // Scroll anchor — real history can be long enough
                        // to open scrolled to the top otherwise (invisible
                        // with the fake's short fixture transcript, but not
                        // with a real, months-long conversation).
                        Color.clear.frame(height: 1).id(Self.bottomAnchorID)
                    }
                    .padding(TIAGASpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                // Otherwise the same swipe that opens the side menu also nudges
                // this scroll position — a human swipe is never perfectly
                // horizontal, and .simultaneousGesture deliberately lets both
                // recognize the same touch at once. See FleetConsoleRootView.
                .scrollDisabled(isSideMenuOpenGestureActive)
                .task {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
                .onChange(of: viewModel.transcript) { _, _ in
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
                .onChange(of: viewModel.isStreaming) { _, _ in
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }

            if let message = viewModel.sendErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            if let message = viewModel.resetErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            ChatComposerBar(
                text: $viewModel.composerText,
                isSendDisabled: viewModel.composerText.isEmpty || viewModel.isStreaming,
                onSend: {
                    Task { await viewModel.send() }
                }
            )
            .id(viewModel.composerResetToken)
            .padding(TIAGASpacing.lg)
        }
        .background(TIAGAColor.background)
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsDynamicUICardBrowser) {
            DynamicUICardBrowserView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Reset conversation?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                Task { await viewModel.reset() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current orchestrator conversation. This can't be undone.")
        }
    }

    private var header: some View {
        VStack(spacing: TIAGASpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                    Text("Context window")
                        .font(TIAGATypography.caption)
                        .foregroundStyle(TIAGAColor.textSecondary)
                    ContextUsageBar(fraction: viewModel.contextUsage.fraction)
                        .frame(height: TIAGASpacing.xs)
                    Text(contextPercentageLabel)
                        .font(TIAGATypography.caption)
                        .foregroundStyle(contextColor)
                }

                Spacer()

                Button {
                    showsDynamicUICardBrowser = true
                } label: {
                    Image(systemName: TIAGAIcon.dynamicUIBrowser)
                        .foregroundStyle(TIAGAColor.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Browse dynamic UI cards")

                Button {
                    showsResetConfirmation = true
                } label: {
                    Image(systemName: TIAGAIcon.reset)
                        .foregroundStyle(TIAGAColor.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(viewModel.isStreaming)
                .accessibilityLabel("Reset conversation")
            }
        }
        .padding(.horizontal, TIAGASpacing.lg)
        .padding(.vertical, TIAGASpacing.md)
    }

    private var contextPercentageLabel: String {
        "\(Int((viewModel.contextUsage.fraction * 100).rounded()))%"
    }

    private var contextColor: Color {
        TIAGAColor.forContextUsage(percentage: viewModel.contextUsage.fraction)
    }

    private static let bottomAnchorID = "bottom"
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
