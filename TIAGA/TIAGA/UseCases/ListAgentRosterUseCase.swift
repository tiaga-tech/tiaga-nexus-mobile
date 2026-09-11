//
//  ListAgentRosterUseCase.swift
//  TIAGA
//

import Foundation

/// Lists the operator's agents for the side menu.
///
/// Business Rule: agents that need attention surface first — running or
/// compacting agents sort before idle, idle before error — so an operator
/// scanning the menu sees what's actively happening before what's stalled.
/// Ties within a bucket break by most-recent activity.
struct ListAgentRosterUseCase {
    let repository: AgentRosterRepository

    func execute() async throws -> [Agent] {
        let agents: [Agent]
        do {
            agents = try await repository.listAgents()
        } catch {
            throw AgentRosterError.fleetUnreachable
        }

        return agents.sorted { lhs, rhs in
            let lhsPriority = Self.priority(for: lhs.state)
            let rhsPriority = Self.priority(for: rhs.state)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }

    private static func priority(for state: AgentState) -> Int {
        switch state {
        case .running, .compacting: return 0
        case .idle: return 1
        case .error: return 2
        }
    }
}
