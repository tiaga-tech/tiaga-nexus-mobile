//
//  CancelAgentTaskUseCase.swift
//  TIAGA
//

import Foundation

/// Cancels an agent's currently running task, backing Agent Chat's stop
/// button.
///
/// Business Rule: only valid while the agent is `.running` — an idle agent
/// has no task to cancel, an agent already in `.error` has already stopped,
/// and a `.compacting` agent has an active operation but not one the
/// operator can interrupt (see `AgentState.compacting`'s own business rule:
/// it's a self-contained transition that must finish on its own).
struct CancelAgentTaskUseCase {
    let repository: AgentRosterRepository

    func execute(agentID: AgentIdentifier) async throws {
        let agents = try await repository.listAgents()
        guard let agent = agents.first(where: { $0.id == agentID }) else {
            throw AgentLifecycleError.agentNoLongerExists
        }
        switch agent.state {
        case .running:
            try await repository.cancelActiveTask(for: agentID)
        case .compacting:
            throw AgentLifecycleError.cannotInterruptCompaction
        case .idle, .error:
            throw AgentLifecycleError.noActiveTaskToCancel
        }
    }
}
