//
//  ResetConversationUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `ResetConversationUseCase` — one controllable
/// busy flag and a reset counter.
private final class StubResetConversationRepository: OrchestratorConversationRepository {
    var shouldBeStreaming = false
    private(set) var resetCallCount = 0

    func send(_ text: String, to target: ConversationTarget) async throws {}

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        AsyncStream { $0.finish() }
    }

    var isStreaming: Bool { shouldBeStreaming }

    func resetConversation() async throws {
        resetCallCount += 1
    }

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] { [] }

    func removeDynamicUICard(id: String) async throws {}

    func cancelCurrentTurn() async throws {}

    func observeDynamicUICardUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

struct ResetConversationUseCaseTests {

    @Test func test_resetConversation_succeeds_whenConversationIsIdle() async throws {
        let repository = StubResetConversationRepository()
        let useCase = ResetConversationUseCase(repository: repository)

        try await useCase.execute()

        #expect(repository.resetCallCount == 1)
    }

    @Test func test_resetConversation_fails_whileConversationIsStreaming() async throws {
        let repository = StubResetConversationRepository()
        repository.shouldBeStreaming = true
        let useCase = ResetConversationUseCase(repository: repository)

        await #expect(throws: ResetConversationError.conversationBusy) {
            try await useCase.execute()
        }
        #expect(repository.resetCallCount == 0)
    }
}
