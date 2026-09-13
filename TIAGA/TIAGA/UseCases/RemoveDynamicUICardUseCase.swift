//
//  RemoveDynamicUICardUseCase.swift
//  TIAGA
//

import Foundation

/// Dismisses one of the orchestrator's dynamic UI cards, backing the Chat
/// screen's card-browser close button.
///
/// The real backend persists cards server-side (`GET /api/cards` restores
/// them after a reload) and exposes `DELETE /api/ui/{id}` specifically so a
/// dismissal survives a reload too — checked `CardsController.cs`/`api.ts`'s
/// `removeDynamicUi` directly; an earlier assumption that this was local-
/// only UI state (mirroring nothing, not verified against the real backend)
/// was wrong.
struct RemoveDynamicUICardUseCase {
    let repository: OrchestratorConversationRepository

    func execute(id: String) async throws {
        try await repository.removeDynamicUICard(id: id)
    }
}
