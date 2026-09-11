//
//  TranscriptEntry.swift
//  TIAGA
//

import Foundation

/// One chronological row in a conversation transcript: either a message or a
/// tool-usage event.
enum TranscriptEntry: Identifiable, Equatable, Sendable {
    case message(ChatMessage)
    case toolUsage(ToolUsageEvent)

    var id: String {
        switch self {
        case .message(let message):
            return "message-\(message.id.uuidString)"
        case .toolUsage(let event):
            return "tool-\(event.id.uuidString)"
        }
    }

    var occurredAt: Date {
        switch self {
        case .message(let message):
            return message.sentAt
        case .toolUsage(let event):
            return event.occurredAt
        }
    }
}

/// Pure, unit-testable transcript merge logic.
///
/// Messages and tool-usage events are stored separately in the domain, then
/// merged into one ordered stream for display — exactly how the real backend
/// collapses `SimpleMessage` rows of kinds `voice`/`tool` into
/// `GetMessageHistory`. Keeping this as a free function means ordering rules
/// can be tested without a repository or ViewModel.
enum TranscriptMerger {
    static func merge(
        messages: [ChatMessage],
        toolUsageEvents: [ToolUsageEvent]
    ) -> [TranscriptEntry] {
        let messageEntries = messages.map(TranscriptEntry.message)
        let toolEntries = toolUsageEvents.map(TranscriptEntry.toolUsage)

        return (messageEntries + toolEntries).sorted { lhs, rhs in
            lhs.occurredAt < rhs.occurredAt
        }
    }
}
