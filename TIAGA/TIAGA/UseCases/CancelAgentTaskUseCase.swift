//
//  CancelAgentTaskUseCase.swift
//  TIAGA
//

import Foundation

/// Cancels an agent's currently running task, backing Agent Chat's stop
/// button.
///
/// Business Rule: only valid while the agent is `.running` or `.compacting`
/// — an idle agent has no task to cancel, and an agent already in `.error`
/// has already stopped.
struct CancelAgentTaskUseCase {
    let repository: AgentRosterRepository

    func execute(agentID: AgentIdentifier) async throws {
        let agents = try await repository.listAgents()
        guard let agent = agents.first(where: { $0.id == agentID }) else {
            throw AgentLifecycleError.agentNoLongerExists
        }
        guard agent.state == .running || agent.state == .compacting else {
            throw AgentLifecycleError.noActiveTaskToCancel
        }

        try await repository.cancelActiveTask(for: agentID)
    }
}
