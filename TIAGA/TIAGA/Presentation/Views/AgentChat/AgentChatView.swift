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
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                    if viewModel.transcript.isEmpty {
                        Text("No messages with \(viewModel.agent?.name ?? "this agent") yet.")
                            .font(TIAGATypography.subheadline)
                            .foregroundStyle(TIAGAColor.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, TIAGASpacing.xl)
                    } else {
                        ForEach(viewModel.transcript) { message in
                            TranscriptRow(message: message, showsKindLabels: false)
                        }
                    }
                }
                .padding(TIAGASpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            // See ChatView for why: the side menu's swipe-to-open gesture
            // shares this touch, and a human swipe is never perfectly
            // horizontal.
            .scrollDisabled(isSideMenuOpenGestureActive)

            if let message = viewModel.sendErrorMessage {
                Text(message)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.statusDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TIAGASpacing.lg)
                    .padding(.top, TIAGASpacing.sm)
            }

            if let message = viewModel.cancelErrorMessage {
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
            if viewModel.canCancelActiveTask {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.cancelActiveTask()
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
    }
}

#Preview {
    NavigationStack {
        AgentChatView(agentID: AgentIdentifier(rawValue: "agent-atlas"), onDeleted: {})
    }
}
