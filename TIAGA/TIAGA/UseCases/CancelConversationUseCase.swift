//
//  CancelConversationUseCase.swift
//  TIAGA
//

import Foundation

/// Cancels the orchestrator's in-flight turn, backing the Chat screen's
/// Stop button (shown in place of Send while a reply is streaming).
///
/// The real backend (`ChatController.Cancel`) never rejects this — history
/// is kept and the cancellation is just noted — so unlike `SendChatMessageUseCase`/
/// `ResetConversationUseCase` there's no client-side business rule to check
/// first; only a genuine connectivity failure can make this fail.
struct CancelConversationUseCase {
    let repository: OrchestratorConversationRepository

    func execute() async throws {
        do {
            try await repository.cancelCurrentTurn()
        } catch {
            throw CancelConversationError.cancelFailed
        }
    }
}
