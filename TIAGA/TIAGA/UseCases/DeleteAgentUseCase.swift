//
//  DeleteAgentUseCase.swift
//  TIAGA
//

import Foundation

/// Deletes an agent, backing Agent Chat's delete button.
///
/// Business Rule: deleting is allowed regardless of state (matches the real
/// product — in-flight tool calls are closed cleanly), but a second delete
/// of an already-gone agent must fail cleanly rather than silently no-op.
struct DeleteAgentUseCase {
    let repository: AgentRosterRepository

    func execute(agentID: AgentIdentifier) async throws {
        try await repository.delete(agentID)
    }
}
