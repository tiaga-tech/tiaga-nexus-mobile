//
//  SendChatMessageUseCase.swift
//  TIAGA
//

import Foundation

/// Sends a text message to a conversation target.
///
/// Reusable for both the orchestrator chat and, later, Agent Chat — the
/// business rules are the same regardless of target.
///
/// Business Rules:
/// 1. The text cannot be empty or whitespace-only.
/// 2. A message cannot be sent while the target is still streaming a reply.
struct SendChatMessageUseCase {
    let repository: OrchestratorConversationRepository

    func execute(text: String, to target: ConversationTarget) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SendChatMessageError.messageIsEmpty
        }

        guard !repository.isStreaming else {
            throw SendChatMessageError.conversationBusy
        }

        try await repository.send(trimmed, to: target)
    }
}
