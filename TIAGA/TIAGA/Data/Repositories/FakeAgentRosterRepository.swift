//
//  FakeAgentRosterRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `AgentRosterRepository` — plain Swift values held in
/// memory, no network calls, ever. See CLAUDE.md's "Testing safety: no live
/// backend" policy. Fixture agents span every `AgentState` so the side
/// menu's sort order and status pills are all actually exercisable.
final class FakeAgentRosterRepository: AgentRosterRepository, @unchecked Sendable {

    /// Set to make `listAgents()` fail, for exercising `.fleetUnreachable`.
    var shouldFail = false

    private let lock = NSLock()
    private var agentsByID: [AgentIdentifier: Agent]
    private var agentOrder: [AgentIdentifier]
    private var continuations: [UUID: (AgentIdentifier, AsyncStream<Agent>.Continuation)] = [:]

    init() {
        let now = Date()
        let fixtureAgents = [
            Agent(
                id: AgentIdentifier(rawValue: "agent-atlas"),
                name: "Atlas",
                state: .running,
                pinnedDeviceName: "Home PC",
                lastActivitySummary: "Redesigning the landing page",
                lastActivityAt: now.addingTimeInterval(-30),
                contextUsageFraction: 0.42
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-comet"),
                name: "Comet",
                state: .compacting,
                pinnedDeviceName: "Work Laptop",
                lastActivitySummary: "Summarising history to free up context",
                lastActivityAt: now.addingTimeInterval(-90),
                contextUsageFraction: 0.97
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-vega"),
                name: "Vega",
                state: .error(reason: "Build failed"),
                pinnedDeviceName: "Home PC",
                lastActivitySummary: "Fix header spacing on the pricing page",
                lastActivityAt: now.addingTimeInterval(-3600),
                contextUsageFraction: 0.61
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-nova"),
                name: "Nova",
                state: .idle,
                pinnedDeviceName: "Server",
                lastActivitySummary: "Waiting for the next instruction",
                lastActivityAt: now.addingTimeInterval(-7200),
                contextUsageFraction: 0.05
            ),
        ]
        agentOrder = fixtureAgents.map(\.id)
        agentsByID = Dictionary(uniqueKeysWithValues: fixtureAgents.map { ($0.id, $0) })
    }

    func listAgents() async throws -> [Agent] {
        if shouldFail {
            throw AgentRosterError.fleetUnreachable
        }
        return lock.withLock { agentOrder.compactMap { agentsByID[$0] } }
    }

    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent> {
        AsyncStream { continuation in
            let subscriptionID = UUID()
            lock.withLock { continuations[subscriptionID] = (id, continuation) }
            if let current = lock.withLock({ agentsByID[id] }) {
                continuation.yield(current)
            }

            let keepAlive = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
                _ = self
            }
            continuation.onTermination = { [weak self] _ in
                keepAlive.cancel()
                self?.removeContinuation(subscriptionID)
            }
        }
    }

    /// Fixture never changes on its own — no pulses to send. Matches
    /// `FakeDeviceFleetRepository.observeDeviceChanges()`.
    func observeRosterChanges() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }

    func cancelActiveTask(for id: AgentIdentifier) async throws {
        guard let agent = lock.withLock({ agentsByID[id] }) else {
            throw AgentLifecycleError.agentNoLongerExists
        }
        switch agent.state {
        case .running:
            break
        case .compacting:
            throw AgentLifecycleError.cannotInterruptCompaction
        case .idle, .error:
            throw AgentLifecycleError.noActiveTaskToCancel
        }

        let cancelled = Agent(
            id: agent.id,
            name: agent.name,
            state: .idle,
            pinnedDeviceName: agent.pinnedDeviceName,
            lastActivitySummary: "Cancelled — waiting for the next instruction",
            lastActivityAt: Date(),
            contextUsageFraction: agent.contextUsageFraction
        )
        lock.withLock { agentsByID[id] = cancelled }
        publish(id, cancelled)
    }

    func delete(_ id: AgentIdentifier) async throws {
        guard lock.withLock({ agentsByID[id] }) != nil else {
            throw AgentLifecycleError.agentNoLongerExists
        }
        lock.withLock {
            agentsByID[id] = nil
            agentOrder.removeAll { $0 == id }
        }
    }

    private func publish(_ id: AgentIdentifier, _ agent: Agent) {
        let matchingContinuations = lock.withLock {
            continuations.values.filter { $0.0 == id }.map(\.1)
        }
        for continuation in matchingContinuations {
            continuation.yield(agent)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.withLock { continuations[id] = nil }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
