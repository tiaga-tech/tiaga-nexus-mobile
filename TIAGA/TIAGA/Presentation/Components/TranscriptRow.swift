//
//  TranscriptRow.swift
//  TIAGA
//

import SwiftUI

/// One chronological transcript row: a chat bubble for a message, or a dim
/// monospaced tool-usage line for an event. Shared by both the orchestrator
/// Chat and Agent Chat — a transcript renders identically either way, only
/// the underlying conversation differs.
struct TranscriptRow: View {
    let entry: TranscriptEntry

    var body: some View {
        switch entry {
        case .message(let message):
            MessageBubble(
                kind: message.role == .operator ? .operatorMessage : .assistantMessage,
                text: message.text
            )
        case .toolUsage(let event):
            MessageBubble(kind: .toolUsage, text: event.summary)
        }
    }
}
