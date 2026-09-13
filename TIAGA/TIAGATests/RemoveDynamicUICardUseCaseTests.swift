//
//  RemoveDynamicUICardUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `RemoveDynamicUICardUseCase` — a removal
/// counter and a failure switch. No domain-specific error case exists for
/// this Use Case (see its own doc comment): a failed removal is low-stakes
/// (the real backend just leaves the card in place for the next reload), so
/// it's a pure pass-through rather than mapping to a typed error — the
/// caller (`ChatViewModel.dismissDynamicCard`) is the one that decides to
/// swallow a failure rather than surface it.
private final class StubRemoveCardRepository: OrchestratorConversationRepository {
    var shouldFail = false
    private(set) var removedIDs: [String] = []

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

    func removeDynamicUICard(id: String) async throws {
        guard !shouldFail else { throw APITransportError.unreachable }
        removedIDs.append(id)
    }

    func cancelCurrentTurn() async throws {}

    func observeDynamicUICardUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

struct RemoveDynamicUICardUseCaseTests {

    @Test func test_removeDynamicUICard_succeeds_removingTheGivenCard() async throws {
        let repository = StubRemoveCardRepository()
        let useCase = RemoveDynamicUICardUseCase(repository: repository)

        try await useCase.execute(id: "card-1")

        #expect(repository.removedIDs == ["card-1"])
    }

    @Test func test_removeDynamicUICard_fails_whenTheBackendIsUnreachable() async throws {
        let repository = StubRemoveCardRepository()
        repository.shouldFail = true
        let useCase = RemoveDynamicUICardUseCase(repository: repository)

        await #expect(throws: APITransportError.unreachable) {
            try await useCase.execute(id: "card-1")
        }
        #expect(repository.removedIDs.isEmpty)
    }
}
