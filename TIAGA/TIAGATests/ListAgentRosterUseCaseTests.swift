//
//  ListAgentRosterUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

private func makeAgent(
    id: String,
    state: AgentState,
    minutesAgo: TimeInterval
) -> Agent {
    Agent(
        id: AgentIdentifier(rawValue: id),
        name: id,
        state: state,
        pinnedDeviceID: DeviceIdentifier(rawValue: "device-1"),
        lastActivitySummary: "doing something",
        lastActivityAt: Date().addingTimeInterval(-minutesAgo * 60),
        contextUsageFraction: 0.1
    )
}

private final class StubAgentRosterRepository: AgentRosterRepository {
    var agents: [Agent] = []
    var shouldFail = false

    func listAgents() async throws -> [Agent] {
        if shouldFail { throw AgentRosterError.fleetUnreachable }
        return agents
    }
}

struct ListAgentRosterUseCaseTests {

    @Test func test_listAgentRoster_ordersRunningAgentsBeforeIdle() async throws {
        let repository = StubAgentRosterRepository()
        repository.agents = [
            makeAgent(id: "idle-agent", state: .idle, minutesAgo: 1),
            makeAgent(id: "running-agent", state: .running, minutesAgo: 5),
        ]
        let useCase = ListAgentRosterUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.id.rawValue) == ["running-agent", "idle-agent"])
    }

    @Test func test_listAgentRoster_ordersErrorAgentsAfterIdle() async throws {
        let repository = StubAgentRosterRepository()
        repository.agents = [
            makeAgent(id: "error-agent", state: .error(reason: "boom"), minutesAgo: 1),
            makeAgent(id: "idle-agent", state: .idle, minutesAgo: 5),
        ]
        let useCase = ListAgentRosterUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.id.rawValue) == ["idle-agent", "error-agent"])
    }

    @Test func test_listAgentRoster_breaksTiesByMostRecentActivity() async throws {
        let repository = StubAgentRosterRepository()
        repository.agents = [
            makeAgent(id: "stale-running", state: .running, minutesAgo: 30),
            makeAgent(id: "fresh-compacting", state: .compacting, minutesAgo: 1),
        ]
        let useCase = ListAgentRosterUseCase(repository: repository)

        let result = try await useCase.execute()

        // Both are in the "running/compacting" bucket — the more recently
        // active one (fresh-compacting) sorts first despite the state differing.
        #expect(result.map(\.id.rawValue) == ["fresh-compacting", "stale-running"])
    }

    @Test func test_listAgentRoster_fails_whenFleetIsUnreachable() async throws {
        let repository = StubAgentRosterRepository()
        repository.shouldFail = true
        let useCase = ListAgentRosterUseCase(repository: repository)

        await #expect(throws: AgentRosterError.fleetUnreachable) {
            _ = try await useCase.execute()
        }
    }
}
