//
//  ResetConversationUseCase.swift
//  TIAGA
//

import Foundation

/// Clears the orchestrator conversation.
///
/// Business Rule: resetting while a response is actively streaming is a
/// data-loss risk mid-stream — reject it instead of discarding the reply the
/// operator is waiting for.
struct ResetConversationUseCase {
    let repository: OrchestratorConversationRepository

    func execute() async throws {
        guard !repository.isStreaming else {
            throw ResetConversationError.conversationBusy
        }

        try await repository.resetConversation()
    }
}
