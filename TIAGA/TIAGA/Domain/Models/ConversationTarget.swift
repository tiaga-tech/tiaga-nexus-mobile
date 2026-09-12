//
//  ConversationTarget.swift
//  TIAGA
//

import Foundation

/// Which conversation a message is being sent to.
///
/// `SendChatMessageUseCase` is deliberately target-agnostic so the same text
/// rules and busy-state guard serve both the main orchestrator chat (Section 5)
/// and the per-agent chat (Section 6) without duplication.
enum ConversationTarget: Equatable, Hashable, Sendable {
    /// TIAGA's main orchestrator conversation.
    case orchestrator
    /// A specific persistent agent's direct conversation.
    case agent(AgentIdentifier)
}
