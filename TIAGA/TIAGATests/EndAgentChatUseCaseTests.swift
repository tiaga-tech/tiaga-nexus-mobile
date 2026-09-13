//
//  EndAgentChatUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `EndAgentChatUseCase` — a handback counter.
/// No failure switch: the real `/handback` endpoint has no failure state
/// the operator could act on, so neither does this fake.
private final class StubEndChatAgentConversationRepository: AgentConversationRepository {
    private(set) var handbackCallCount = 0

    func send(_ text: String, to agentID: AgentIdentifier) async throws {}

    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func interruptActiveTask(for agentID: AgentIdentifier) async throws {}

    func endChat(with agentID: AgentIdentifier) async {
        handbackCallCount += 1
    }
}

struct EndAgentChatUseCaseTests {

    @Test func test_endAgentChat_handsTheAgentBackToTheOrchestrator() async throws {
        let repository = StubEndChatAgentConversationRepository()
        let useCase = EndAgentChatUseCase(repository: repository)

        await useCase.execute(agentID: AgentIdentifier(rawValue: "agent-1"))

        #expect(repository.handbackCallCount == 1)
    }
}
