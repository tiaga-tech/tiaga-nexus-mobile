//
//  CancelAgentTaskUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

private func makeAgent(id: String, state: AgentState) -> Agent {
    Agent(
        id: AgentIdentifier(rawValue: id),
        name: id,
        state: state,
        pinnedDeviceName: "Device One",
        lastActivitySummary: "doing something",
        lastActivityAt: Date(),
        contextUsageFraction: 0.1
    )
}

/// Thin purpose-built fake for `CancelAgentTaskUseCase` — a single
/// controllable agent and a cancel-call counter.
private final class StubAgentRosterRepository: AgentRosterRepository {
    var agent: Agent?
    private(set) var cancelCallCount = 0

    func listAgents() async throws -> [Agent] {
        agent.map { [$0] } ?? []
    }

    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent> {
        AsyncStream { $0.finish() }
    }

    func observeRosterChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    func cancelActiveTask(for id: AgentIdentifier) async throws {
        cancelCallCount += 1
    }

    func delete(_ id: AgentIdentifier) async throws {}
}

struct CancelAgentTaskUseCaseTests {

    @Test func test_cancelAgentTask_succeeds_whenAgentIsRunning() async throws {
        let repository = StubAgentRosterRepository()
        repository.agent = makeAgent(id: "agent-1", state: .running)
        let useCase = CancelAgentTaskUseCase(repository: repository)

        try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))

        #expect(repository.cancelCallCount == 1)
    }

    @Test func test_cancelAgentTask_fails_whenAgentIsCompacting() async throws {
        // Compacting has an active operation, but per AgentState.compacting's
        // own business rule it's self-contained and can't be interrupted —
        // this must NOT succeed just because something is happening.
        let repository = StubAgentRosterRepository()
        repository.agent = makeAgent(id: "agent-1", state: .compacting)
        let useCase = CancelAgentTaskUseCase(repository: repository)

        await #expect(throws: AgentLifecycleError.cannotInterruptCompaction) {
            try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))
        }
        #expect(repository.cancelCallCount == 0)
    }

    @Test func test_cancelAgentTask_fails_whenAgentIsIdle() async throws {
        let repository = StubAgentRosterRepository()
        repository.agent = makeAgent(id: "agent-1", state: .idle)
        let useCase = CancelAgentTaskUseCase(repository: repository)

        await #expect(throws: AgentLifecycleError.noActiveTaskToCancel) {
            try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))
        }
        #expect(repository.cancelCallCount == 0)
    }

    @Test func test_cancelAgentTask_fails_whenAgentNoLongerExists() async throws {
        let repository = StubAgentRosterRepository()
        repository.agent = nil
        let useCase = CancelAgentTaskUseCase(repository: repository)

        await #expect(throws: AgentLifecycleError.agentNoLongerExists) {
            try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))
        }
        #expect(repository.cancelCallCount == 0)
    }
}
