//
//  AgentChatView.swift
//  TIAGA
//

import SwiftUI

/// One agent's direct conversation: its own transcript, a composer gated by
/// the agent's live state, a stop button shown only while there's an active
/// task, and a delete button (with a destructive/cancel confirmation,
/// matching Chat's reset dialog).
struct AgentChatView: View {
    @StateObject private var viewModel: AgentChatViewModel
    @State private var showsDeleteConfirmation = false
    @Environment(\.isSideMenuOpenGestureActive) private var isSideMenuOpenGestureActive
    let onDeleted: () -> Void
    let onRosterChanged: () -> Void

    /// `agentRosterRepository`/`agentConversationRepository` default to a
    /// fresh fake for previews/standalone use, but the real call site
    /// (`FleetConsoleRootView`) must pass its own shared instances — a
    /// second, unrelated fake here wouldn't see (or reflect back) anything
    /// the side menu's own roster does, which is exactly the bug where a
    /// delete never left the menu.
    init(
        agentID: AgentIdentifier,
        agentRosterRepository: AgentRosterRepository = FakeAgentRosterRepository(),
        agentConversationRepository: AgentConversationRepository = FakeAgentConversationRepository(),
        onDeleted: @escaping () -> Void,
        onRosterChanged: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: AgentChatViewModel(
            agentID: agentID,
            agentRosterRepository: agentRosterRepository,
            agentConversationRepository: agentConversationRepository
        ))
        self.onDeleted = onDeleted
        self.onRosterChanged = onRosterChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            if let agent = viewModel.agent {
                HStack {
                    StatusPill(agentState: agent.state)
                    Spacer()
                }
                .padding(.horizontal, TIAGASpacing.lg)
                .padding(.top, TIAGASpacing.sm)
                .padding(.bottom, TIAGASpacing.sm)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    // A plain VStack, not LazyVStack: a direct chat with one
                    // agent is nowhere near long enough to need laziness,
                    // and LazyVStack was the actual cause of the "scrolls to
                    // a blank area" bug — scrollTo(anchor:) on a lazy stack
                    // targets an *estimated* position for rows it hasn't
                    // measured yet, which can overshoot past the real
                    // (shorter) content into that estimated-but-never-
                    // rendered space. A fully-measured VStack has no
                    // estimate to get wrong.
                    VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                        if viewModel.transcript.isEmpty {
                            Text("No messages with \(viewModel.agent?.name ?? "this agent") yet.")
                                .font(TIAGATypography.subheadline)
                                .foregroundStyle(TIAGAColor.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, TIAGASpacing.xl)
                        } else {
                            ForEach(viewModel.transcript) { message in
                                TranscriptRow(message: message)
                            }
                        }

                        // See ChatView for why: real history can be long
                        // enough to open scrolled to the top otherwise.
                        Color.clear.frame(height: 1).id(Self.bottomAnchorID)
                    }
                    .padding(TIAGASpacing.lg)
                }
                // Positions the scroll view at the bottom from its very
                // first rendered frame — no visible jump, matching ChatView.
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                // See ChatView for why: the side menu's swipe-to-open gesture
                // shares this touch, and a human swipe is never perfectly
                // horizontal.
                .scrollDisabled(isSideMenuOpenGestureActive)
                .onChange(of: viewModel.transcript) { _, _ in
                    Task { await scrollToBottom(proxy) }
                }
                // The status pill header only appears once `observeAgent`'s
                // async fetch resolves — arriving after the transcript has
                // already settled would shrink the scroll view's available
                // height from the top without anything here re-anchoring
                // to the (now-shifted) bottom. Re-scrolling on this change
                // too closes that gap.
                .onChange(of: viewModel.agent) { _, _ in
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

            if let message = viewModel.interruptErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            if let message = viewModel.deleteErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            ChatComposerBar(
                text: $viewModel.composerText,
                isSendDisabled: viewModel.composerText.isEmpty || viewModel.isComposerDisabled,
                onSend: {
                    Task { await viewModel.send() }
                }
            )
            .padding(TIAGASpacing.lg)
        }
        .background(TIAGAColor.background)
        .navigationTitle(viewModel.agent?.name ?? "Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canInterruptActiveTask {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.interruptActiveTask()
                            onRosterChanged()
                        }
                    } label: {
                        Image(systemName: TIAGAIcon.cancelTask)
                            .foregroundStyle(TIAGAColor.statusDanger)
                    }
                    .accessibilityLabel("Stop current task")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Image(systemName: TIAGAIcon.deleteAgent)
                        .foregroundStyle(TIAGAColor.statusDanger)
                }
                .accessibilityLabel("Delete agent")
            }
        }
        .confirmationDialog(
            "Delete this agent?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes \(viewModel.agent?.name ?? "this agent") and its conversation. This can't be undone.")
        }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                onRosterChanged()
                onDeleted()
            }
        }
        // Hands the agent back to orchestrator control the moment the
        // operator leaves this screen — matches the real web client's own
        // chat-window close behavior (`useAgentChat.ts`'s `close()`).
        .onDisappear {
            Task { await viewModel.endChat() }
        }
    }

    private static let bottomAnchorID = "bottom"

    /// See `ChatView.scrollToBottom(_:)` — the same `LazyVStack` layout-
    /// timing fix, retrying a couple of times shortly after a transcript
    /// change so it lands at the true bottom once layout has settled.
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
        AgentChatView(agentID: AgentIdentifier(rawValue: "agent-atlas"), onDeleted: {})
    }
}
