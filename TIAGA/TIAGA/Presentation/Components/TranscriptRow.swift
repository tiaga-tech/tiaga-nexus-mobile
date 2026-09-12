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
/// Matches the real product's `AgentChatWindow.tsx` styling for both
/// screens: no kind labels, and `.tool` renders as a plain dim monospaced
/// line rather than a bordered bubble, since it's showing what actually
/// happened, not something being said.
struct TranscriptRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .operator:
            row(alignTrailing: true) {
                MessageBubble(kind: .operatorMessage, text: message.text)
            }

        case .orchestrator:
            switch message.kind {
            case .tool:
                MessageBubble(kind: .toolLine, text: message.text)
            case .error:
                row(alignTrailing: false) {
                    MessageBubble(kind: .errorMessage, text: message.text)
                }
            case .voice, .context, .task, .ui:
                row(alignTrailing: false) {
                    MessageBubble(kind: .assistantMessage, text: message.text)
                }
            }
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
        }
        .padding()
    }
    .background(TIAGAColor.background)
}
