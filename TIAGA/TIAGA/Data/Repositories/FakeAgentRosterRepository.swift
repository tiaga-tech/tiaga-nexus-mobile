//
//  FakeAgentRosterRepository.swift
//  TIAGA
//

import Foundation

/// Fixture-backed `AgentRosterRepository` — plain Swift values held in
/// memory, no network calls, ever. See CLAUDE.md's "Testing safety: no live
/// backend" policy. Fixture agents span every `AgentState` so the side
/// menu's sort order and status pills are all actually exercisable.
final class FakeAgentRosterRepository: AgentRosterRepository {

    /// Set to make `listAgents()` fail, for exercising `.fleetUnreachable`.
    var shouldFail = false

    private let fixtureAgents: [Agent]

    init() {
        let now = Date()
        fixtureAgents = [
            Agent(
                id: AgentIdentifier(rawValue: "agent-atlas"),
                name: "Atlas",
                state: .running,
                pinnedDeviceID: DeviceIdentifier(rawValue: "device-home-pc"),
                lastActivitySummary: "Redesigning the landing page",
                lastActivityAt: now.addingTimeInterval(-30),
                contextUsageFraction: 0.42
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-comet"),
                name: "Comet",
                state: .compacting,
                pinnedDeviceID: DeviceIdentifier(rawValue: "device-work-laptop"),
                lastActivitySummary: "Summarising history to free up context",
                lastActivityAt: now.addingTimeInterval(-90),
                contextUsageFraction: 0.97
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-vega"),
                name: "Vega",
                state: .error(reason: "Build failed"),
                pinnedDeviceID: DeviceIdentifier(rawValue: "device-home-pc"),
                lastActivitySummary: "Fix header spacing on the pricing page",
                lastActivityAt: now.addingTimeInterval(-3600),
                contextUsageFraction: 0.61
            ),
            Agent(
                id: AgentIdentifier(rawValue: "agent-nova"),
                name: "Nova",
                state: .idle,
                pinnedDeviceID: DeviceIdentifier(rawValue: "device-server"),
                lastActivitySummary: "Waiting for the next instruction",
                lastActivityAt: now.addingTimeInterval(-7200),
                contextUsageFraction: 0.05
            ),
        ]
    }

    func listAgents() async throws -> [Agent] {
        if shouldFail {
            throw AgentRosterError.fleetUnreachable
        }
        return fixtureAgents
    }
}
