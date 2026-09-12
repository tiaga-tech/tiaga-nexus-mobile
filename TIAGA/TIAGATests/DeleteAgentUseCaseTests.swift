//
//  DeleteAgentUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `DeleteAgentUseCase` — a mutable single-agent
/// store so a second delete of the same id can be exercised honestly.
private final class StubAgentRosterRepository: AgentRosterRepository {
    var agentExists = true

    func listAgents() async throws -> [Agent] { [] }

    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent> {
        AsyncStream { $0.finish() }
    }

    func cancelActiveTask(for id: AgentIdentifier) async throws {}

    func delete(_ id: AgentIdentifier) async throws {
        guard agentExists else {
            throw AgentLifecycleError.agentNoLongerExists
        }
        agentExists = false
    }
}

struct DeleteAgentUseCaseTests {

    @Test func test_deleteAgent_succeeds_whenAgentExists() async throws {
        let repository = StubAgentRosterRepository()
        let useCase = DeleteAgentUseCase(repository: repository)

        try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))

        #expect(repository.agentExists == false)
    }

    @Test func test_deleteAgent_fails_whenAgentAlreadyDeleted() async throws {
        let repository = StubAgentRosterRepository()
        let useCase = DeleteAgentUseCase(repository: repository)
        try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))

        await #expect(throws: AgentLifecycleError.agentNoLongerExists) {
            try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))
        }
    }
}
