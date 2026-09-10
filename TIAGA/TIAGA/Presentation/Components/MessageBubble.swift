//
//  MessageBubble.swift
//  TIAGA
//

import SwiftUI

/// A single row in a conversation transcript (used by both the orchestrator
/// Chat and Agent Chat). `.toolUsage` renders in the monospaced command font
/// since it's showing what the assistant/agent actually did, not prose.
struct MessageBubble: View {
    enum Kind {
        case operatorMessage
        case assistantMessage
        case toolUsage
    }

    let kind: Kind
    let text: String

    var body: some View {
        HStack {
            if kind == .operatorMessage { Spacer(minLength: TIAGASpacing.xxl) }
            Text(text)
                .font(kind == .toolUsage ? TIAGATypography.command : TIAGATypography.body)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, TIAGASpacing.md)
                .padding(.vertical, TIAGASpacing.sm)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.md, style: .continuous))
            if kind != .operatorMessage { Spacer(minLength: TIAGASpacing.xxl) }
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .operatorMessage: return TIAGAColor.brandAccent.opacity(0.15)
        case .assistantMessage: return TIAGAColor.surface
        case .toolUsage: return TIAGAColor.surfaceElevated
        }
    }

    private var foregroundColor: Color {
        kind == .toolUsage ? TIAGAColor.textSecondary : TIAGAColor.textPrimary
    }
}

#Preview {
    VStack(spacing: TIAGASpacing.sm) {
        MessageBubble(kind: .operatorMessage, text: "Redesign the landing page on the home PC.")
        MessageBubble(kind: .assistantMessage, text: "On it — spawning Atlas on Home PC.")
        MessageBubble(kind: .toolUsage, text: "edit web/src/App.tsx")
    }
    .padding()
    .background(TIAGAColor.background)
}
