//
//  MessageBubble.swift
//  TIAGA
//

import SwiftUI

/// One message's own content — used by both the orchestrator Chat and Agent
/// Chat, matching the real product's own chat styling. Left/right alignment
/// (and, for Chat, the kind label above) is `TranscriptRow`'s job, not
/// this view's — `MessageBubble` only renders the content itself.
struct MessageBubble: View {
    enum Kind {
        /// The operator's own message — filled with the brand accent.
        case operatorMessage
        /// A plain spoken reply from the orchestrator or an agent — a flat
        /// translucent surface. Also used for `.context`/`.task`/`.ui` kinds,
        /// which the real web client doesn't tint differently either.
        case assistantMessage
        /// Chat's rich tool-call rendering: a bordered, amber-tinted
        /// monospace bubble (matches `MessageList.tsx`).
        case toolBubble
        /// Agent Chat's simple tool-call rendering: a plain dim monospaced
        /// line, never a bubble, since it's showing what actually happened,
        /// not something being said (matches `AgentChatWindow.tsx`).
        case toolLine
        /// A bordered, red-tinted bubble for a `.error`-kind message —
        /// visually distinct from the orchestrator/agent's own words, since
        /// this is fixed status copy, not AI-generated speech (matches both
        /// `MessageList.tsx` and `AgentChatWindow.tsx`).
        case errorMessage
    }

    let kind: Kind
    let text: String

    var body: some View {
        switch kind {
        case .toolLine:
            HStack(spacing: TIAGASpacing.xs) {
                Image(systemName: TIAGAIcon.toolBash)
                    .font(TIAGATypography.caption)
                Text(text)
                    .font(TIAGATypography.command)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(TIAGAColor.textTertiary)

        case .toolBubble:
            Text(text)
                .font(TIAGATypography.command)
                .foregroundStyle(TIAGAColor.statusWarning)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(TIAGAColor.statusWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous)
                        .strokeBorder(TIAGAColor.statusWarning.opacity(0.2), lineWidth: 1)
                )

        case .errorMessage:
            Text(text)
                .font(TIAGATypography.body)
                .foregroundStyle(TIAGAColor.statusDanger)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(TIAGAColor.statusDanger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous)
                        .strokeBorder(TIAGAColor.statusDanger.opacity(0.2), lineWidth: 1)
                )

        case .operatorMessage, .assistantMessage:
            Text(text)
                .font(TIAGATypography.body)
                .foregroundStyle(kind == .operatorMessage ? TIAGAColor.textOnAccent : TIAGAColor.textPrimary)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(kind == .operatorMessage ? TIAGAColor.brandAccent.opacity(0.8) : TIAGAColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
        MessageBubble(kind: .operatorMessage, text: "Redesign the landing page on the home PC.")
        MessageBubble(kind: .assistantMessage, text: "On it — spawning Atlas on Home PC.")
        MessageBubble(kind: .toolBubble, text: "agent: Restart backend for new model")
        MessageBubble(kind: .toolLine, text: "edit web/src/App.tsx")
        MessageBubble(kind: .errorMessage, text: "The server restarted while agents were working. Their progress is saved.")
    }
    .padding()
    .background(TIAGAColor.background)
}
