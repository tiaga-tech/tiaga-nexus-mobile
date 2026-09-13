//
//  CancelConversationUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `CancelConversationUseCase` — a cancel
/// counter and a failure switch.
private final class StubCancelConversationRepository: OrchestratorConversationRepository {
    var shouldFail = false
    private(set) var cancelCallCount = 0

    func send(_ text: String, to target: ConversationTarget) async throws {}

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        AsyncStream { $0.finish() }
    }

    var isStreaming: Bool { false }

    func resetConversation() async throws {}

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] { [] }

    func removeDynamicUICard(id: String) async throws {}

    func cancelCurrentTurn() async throws {
        guard !shouldFail else { throw CancelConversationError.cancelFailed }
        cancelCallCount += 1
    }

    func observeDynamicUICardUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

struct CancelConversationUseCaseTests {

    @Test func test_cancelConversation_succeeds_stoppingTheInFlightTurn() async throws {
        let repository = StubCancelConversationRepository()
        let useCase = CancelConversationUseCase(repository: repository)

        try await useCase.execute()

        #expect(repository.cancelCallCount == 1)
    }

    @Test func test_cancelConversation_fails_whenBackendIsUnreachable() async throws {
        let repository = StubCancelConversationRepository()
        repository.shouldFail = true
        let useCase = CancelConversationUseCase(repository: repository)

        await #expect(throws: CancelConversationError.cancelFailed) {
            try await useCase.execute()
        }
        #expect(repository.cancelCallCount == 0)
    }
}
