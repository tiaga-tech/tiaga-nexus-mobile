//
//  LoadDynamicUICardHistoryUseCase.swift
//  TIAGA
//

import Foundation

/// Loads the orchestrator's dynamic UI card history, backing the "browse
/// dynamic UI" entry point on the Chat screen.
struct LoadDynamicUICardHistoryUseCase {
    let repository: OrchestratorConversationRepository

    func execute() async throws -> [DynamicUICard] {
        do {
            return try await repository.fetchDynamicUICardHistory()
        } catch {
            throw DynamicUICardHistoryError.unavailable
        }
    }
}
