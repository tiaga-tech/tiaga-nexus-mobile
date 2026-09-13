//
//  ChatView.swift
//  TIAGA
//

import SwiftUI

/// The main orchestrator chat screen: a text-only transcript that interleaves
/// messages and tool-usage events, the shared composer, a reset button, the
/// context-usage bar, and an entry point into the dynamic UI card history.
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var showsDynamicUICardBrowser = false
    @State private var showsResetConfirmation = false
    @Environment(\.isSideMenuOpenGestureActive) private var isSideMenuOpenGestureActive

    /// `repository` defaults to a fresh fake for previews/standalone use,
    /// but the real call site (`FleetConsoleRootView`) must pass its own
    /// shared, persistent instance — matching the real web client, which
    /// mounts its orchestrator conversation state once for the whole
    /// session rather than per-visit. See `FleetConsoleRootView`'s own
    /// `orchestratorConversationRepository` doc comment for why a fresh
    /// instance per visit caused real bugs (a confirmed subscription leak,
    /// and even after fixing that, races that could show stale "replying"
    /// state or fail to load on return to Chat).
    init(repository: OrchestratorConversationRepository = FakeOrchestratorConversationRepository()) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(repository: repository))
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
                // Positions the scroll view at the bottom from its very
                // first rendered frame — no visible jump/animation the way
                // an explicit `scrollTo` call after appearing would show,
                // matching how other chat apps open already at the latest
                // message rather than visibly scrolling there.
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                // Otherwise the same swipe that opens the side menu also nudges
                // this scroll position — a human swipe is never perfectly
                // horizontal, and .simultaneousGesture deliberately lets both
                // recognize the same touch at once. See FleetConsoleRootView.
                .scrollDisabled(isSideMenuOpenGestureActive)
                .onChange(of: viewModel.transcript) { _, _ in
                    Task { await scrollToBottom(proxy) }
                }
                .onChange(of: viewModel.isStreaming) { _, _ in
                    Task { await scrollToBottom(proxy) }
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
                isSendDisabled: viewModel.composerText.isEmpty,
                isStreaming: viewModel.isStreaming,
                onSend: {
                    Task { await viewModel.send() }
                },
                onStop: {
                    Task { await viewModel.stop() }
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
                .overlay(alignment: .topTrailing) {
                    if viewModel.hasUnseenDynamicUICardUpdate {
                        Circle()
                            .fill(TIAGAColor.statusDanger)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
                .accessibilityLabel(
                    viewModel.hasUnseenDynamicUICardUpdate
                        ? "Browse dynamic UI cards, new card available"
                        : "Browse dynamic UI cards"
                )

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

    /// A single `scrollTo` right after real (potentially long) history
    /// loads can land mid-conversation instead of at the bottom: the
    /// `LazyVStack` above the anchor hasn't measured all of the newly-
    /// inserted rows yet, so `ScrollViewReader` computes the target
    /// position from an incomplete layout. Retrying a couple of times
    /// shortly after — by which point layout has settled — corrects it
    /// without giving up `LazyVStack`'s laziness for a long conversation.
    private func scrollToBottom(_ proxy: ScrollViewProxy) async {
        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        try? await Task.sleep(nanoseconds: 100_000_000)
        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        try? await Task.sleep(nanoseconds: 300_000_000)
        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
