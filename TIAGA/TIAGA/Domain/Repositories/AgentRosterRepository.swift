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

    /// The live state of one agent — Agent Chat uses this to reactively
    /// disable its composer and show/hide the stop button as the agent
    /// moves through its lifecycle, without the operator needing to attempt
    /// a send to discover it's blocked.
    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent>

    /// Cancels the agent's current task, returning it to `.idle`. Callers
    /// go through `CancelAgentTaskUseCase`, which enforces the
    /// running/compacting-only business rule before calling this.
    func cancelActiveTask(for id: AgentIdentifier) async throws

    /// Deletes the agent. Throws `AgentLifecycleError.agentNoLongerExists`
    /// if it's already gone.
    func delete(_ id: AgentIdentifier) async throws
}
