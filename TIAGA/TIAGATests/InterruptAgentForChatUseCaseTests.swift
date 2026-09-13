//
//  InterruptAgentForChatUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `InterruptAgentForChatUseCase` — an
/// interrupt counter and a failure switch.
private final class StubInterruptAgentConversationRepository: AgentConversationRepository {
    var shouldFail = false
    private(set) var interruptCallCount = 0

    func send(_ text: String, to agentID: AgentIdentifier) async throws {}

    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func interruptActiveTask(for agentID: AgentIdentifier) async throws {
        guard !shouldFail else { throw AgentLifecycleError.agentNoLongerExists }
        interruptCallCount += 1
    }

    func endChat(with agentID: AgentIdentifier) async {}
}

struct InterruptAgentForChatUseCaseTests {

    @Test func test_interruptAgentForChat_succeeds_takingOverAnyState() async throws {
        // Unlike CancelAgentTaskUseCase, the real /interrupt endpoint has no
        // "wrong state" business rule — it always succeeds if the agent
        // exists, even calling it on an already-idle agent.
        let repository = StubInterruptAgentConversationRepository()
        let useCase = InterruptAgentForChatUseCase(repository: repository)

        try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))

        #expect(repository.interruptCallCount == 1)
    }

    @Test func test_interruptAgentForChat_fails_whenAgentNoLongerExists() async throws {
        let repository = StubInterruptAgentConversationRepository()
        repository.shouldFail = true
        let useCase = InterruptAgentForChatUseCase(repository: repository)

        await #expect(throws: AgentLifecycleError.agentNoLongerExists) {
            try await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))
        }
        #expect(repository.interruptCallCount == 0)
    }
}
