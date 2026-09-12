//
//  ChatMessage.swift
//  TIAGA
//

import Foundation

/// Who authored a line in a conversation transcript.
enum ChatMessageRole: String, Equatable, Sendable {
    /// A human operator using the mobile console.
    case `operator`
    /// TIAGA's orchestrator — the assistant that plans and dispatches work.
    case orchestrator
}

/// One line in the orchestrator conversation transcript.
///
/// Represents the real backend's `SimpleMessage` transcript shape (`Role`,
/// `Text`, and its chronological place in `GetMessageHistory`), reduced to
/// the text-only fields this app renders. Voice is out of scope, so there is
/// no spoken/display split here.
///
/// Business Rule: messages and tool-usage events are separate transcript
/// kinds, merged chronologically for display — see `TranscriptMerger`.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: ChatMessageRole
    let text: String
    let sentAt: Date

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.sentAt = sentAt
    }
}
