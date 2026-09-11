//
//  AgentRosterRepository.swift
//  TIAGA
//

import Foundation

/// The operator's fleet of agents. Protocol only — see
/// `Data/Repositories/FakeAgentRosterRepository.swift` for the (fixture-
/// backed, no-network) implementation. Never call this directly from a
/// View; go through a Use Case.
protocol AgentRosterRepository {
    func listAgents() async throws -> [Agent]
}
