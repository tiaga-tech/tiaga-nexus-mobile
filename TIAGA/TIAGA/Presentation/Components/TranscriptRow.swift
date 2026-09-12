//
//  TranscriptRow.swift
//  TIAGA
//

import SwiftUI

/// One chronological transcript row, shared by both the orchestrator Chat
/// and Agent Chat — a `ChatMessage`'s `role` picks left/right alignment and
/// its `kind` picks the bubble style, mirroring the real backend exactly
/// (there's no separate "tool usage" or "error" domain type; they're the
/// same `ChatMessage` with a different `kind`).
///
/// Chat's transcript labels each non-operator kind with a small colored dot
/// + name above the bubble (matching the real web client's
/// `MessageList.tsx`); Agent Chat's is simpler — matching
/// `AgentChatWindow.tsx` — no labels, and `.tool` renders as a plain dim
/// monospaced line rather than a bordered bubble, since the real agent-chat
/// wire format has no separate kind at all, just a widened role.
struct TranscriptRow: View {
    let message: ChatMessage
    var showsKindLabels = true

    var body: some View {
        switch message.role {
        case .operator:
            row(alignTrailing: true) {
                MessageBubble(kind: .operatorMessage, text: message.text)
            }

        case .orchestrator:
            if message.kind == .tool, !showsKindLabels {
                MessageBubble(kind: .toolLine, text: message.text)
            } else {
                row(alignTrailing: false) {
                    VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                        if showsKindLabels {
                            kindLabel
                        }
                        MessageBubble(kind: bubbleKind, text: message.text)
                    }
                }
            }
        }
    }

    private var bubbleKind: MessageBubble.Kind {
        switch message.kind {
        case .tool: return .toolBubble
        case .error: return .errorMessage
        case .voice, .context, .task, .ui: return .assistantMessage
        }
    }

    private var kindLabel: some View {
        HStack(spacing: TIAGASpacing.xs) {
            Circle()
                .fill(TIAGAColor.forChatMessageKind(message.kind))
                .frame(width: 6, height: 6)
            Text(message.kind.displayLabel.uppercased())
                .font(TIAGATypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(TIAGAColor.forChatMessageKind(message.kind))
        }
    }

    @ViewBuilder
    private func row(alignTrailing: Bool, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            if alignTrailing { Spacer(minLength: TIAGASpacing.xxl) }
            content()
            if !alignTrailing { Spacer(minLength: TIAGASpacing.xxl) }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
            TranscriptRow(message: ChatMessage(role: .operator, text: "How is the landing page build going?"))
            TranscriptRow(message: ChatMessage(role: .orchestrator, kind: .tool, text: "agent: Restart backend for new model"))
            TranscriptRow(message: ChatMessage(role: .orchestrator, kind: .voice, text: "On it — restarting the backend with the new model settings."))
            TranscriptRow(message: ChatMessage(role: .orchestrator, kind: .error, text: "The server restarted while agents were working. Their progress is saved."))
            Divider()
            TranscriptRow(message: ChatMessage(role: .orchestrator, kind: .tool, text: "bash: echo alive && date -u"), showsKindLabels: false)
            TranscriptRow(message: ChatMessage(role: .orchestrator, kind: .error, text: "Stopped partway: the server restarted for an update."), showsKindLabels: false)
        }
        .padding()
    }
    .background(TIAGAColor.background)
}
