//
//  MessageBubble.swift
//  TIAGA
//

import SwiftUI

/// A single row in a conversation transcript (used by both the orchestrator
/// Chat and Agent Chat), matching the real product's own chat styling:
/// the operator's own messages are filled with the brand accent, the
/// assistant/agent's replies sit on a flat translucent surface, and tool
/// usage renders as a plain dim monospaced line — never a bubble — since it's
/// showing what actually happened, not something being said.
struct MessageBubble: View {
    enum Kind {
        case operatorMessage
        case assistantMessage
        case toolUsage
    }

    let kind: Kind
    let text: String

    var body: some View {
        switch kind {
        case .toolUsage:
            HStack(spacing: TIAGASpacing.xs) {
                Image(systemName: TIAGAIcon.toolBash)
                    .font(TIAGATypography.caption)
                Text(text)
                    .font(TIAGATypography.command)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(TIAGAColor.textTertiary)

        case .operatorMessage, .assistantMessage:
            HStack {
                if kind == .operatorMessage { Spacer(minLength: TIAGASpacing.xxl) }
                Text(text)
                    .font(TIAGATypography.body)
                    .foregroundStyle(kind == .operatorMessage ? TIAGAColor.textOnAccent : TIAGAColor.textPrimary)
                    .padding(.horizontal, TIAGASpacing.md)
                    .padding(.vertical, TIAGASpacing.sm)
                    .background(kind == .operatorMessage ? TIAGAColor.brandAccent.opacity(0.8) : TIAGAColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.lg, style: .continuous))
                if kind == .assistantMessage { Spacer(minLength: TIAGASpacing.xxl) }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
        MessageBubble(kind: .operatorMessage, text: "Redesign the landing page on the home PC.")
        MessageBubble(kind: .assistantMessage, text: "On it — spawning Atlas on Home PC.")
        MessageBubble(kind: .toolUsage, text: "edit web/src/App.tsx")
    }
    .padding()
    .background(TIAGAColor.background)
}
