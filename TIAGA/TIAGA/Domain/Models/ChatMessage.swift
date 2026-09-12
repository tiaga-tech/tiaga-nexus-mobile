//
//  ChatMessage.swift
//  TIAGA
//

import Foundation

/// Who authored a line in a conversation transcript.
enum ChatMessageRole: String, Equatable, Sendable {
    /// A human operator using the mobile console.
    case `operator`
    /// The AI side of the conversation — TIAGA's orchestrator in the main
    /// Chat screen, or the pinned agent itself in Agent Chat. Which one it
    /// is depends entirely on which conversation this message belongs to;
    /// the role only distinguishes "the operator" from "not the operator".
    case orchestrator
}

/// What kind of content a `.orchestrator`-authored message carries, mirroring
/// the real web client's `MessageKind` (`web/src/types.ts`) exactly: a plain
/// spoken reply, a tool call, a context-compaction notice, a task update, a
/// dynamic-UI-card announcement, or an error. Meaningless for `.operator`
/// messages (the web client never sets it on a `role: 'user'` message
/// either) — the transcript UI never labels a `.operator` message.
enum ChatMessageKind: String, Equatable, Sendable {
    case voice
    case tool
    case context
    case task
    case ui
    case error

    /// The operator-facing label shown above a message in the transcript,
    /// matching the real web client's kind indicator (see `MessageList.tsx`).
    var displayLabel: String {
        switch self {
        case .voice: return "Voice"
        case .tool: return "Tool"
        case .context: return "Context"
        case .task: return "Task"
        case .ui: return "UI"
        case .error: return "Error"
        }
    }
}

/// One line in a conversation transcript — the orchestrator's own chat, or
/// one agent's direct chat (see `ConversationTarget`).
///
/// Represents the real backend's message shape directly: `role` (who's
/// speaking) and `kind` (what type of content this is) are independent axes,
/// exactly like the web client's `Message`/`AgentChatMsg` — there is no
/// separate "tool usage" or "error" domain type; those are just this same
/// `ChatMessage` with a different `kind`. `kind` defaults to `.voice`, the
/// plain "the AI side said something" case.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: ChatMessageRole
    let kind: ChatMessageKind
    let text: String
    let sentAt: Date

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        kind: ChatMessageKind = .voice,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.text = text
        self.sentAt = sentAt
    }
}
