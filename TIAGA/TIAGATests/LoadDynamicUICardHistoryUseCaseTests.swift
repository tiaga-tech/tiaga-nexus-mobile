//
//  LoadDynamicUICardHistoryUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `LoadDynamicUICardHistoryUseCase` — a
/// controllable card list and a failure switch.
private final class StubDynamicCardHistoryRepository: OrchestratorConversationRepository {
    var cards: [DynamicUICard] = []
    var shouldFail = false

    func send(_ text: String, to target: ConversationTarget) async throws {}

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        AsyncStream { $0.finish() }
    }

    var isStreaming: Bool { false }

    func resetConversation() async throws {}

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] {
        guard !shouldFail else { throw APITransportError.unreachable }
        return cards
    }

    func removeDynamicUICard(id: String) async throws {}

    func cancelCurrentTurn() async throws {}

    func observeDynamicUICardUpdates() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

struct LoadDynamicUICardHistoryUseCaseTests {

    @Test func test_loadDynamicUICardHistory_succeeds_returningThePersistedCards() async throws {
        let repository = StubDynamicCardHistoryRepository()
        repository.cards = [
            DynamicUICard(
                id: "card-1",
                title: "Landing page mockup",
                kind: .code,
                text: nil,
                code: "console.log('hi')",
                language: "javascript",
                columns: nil,
                rows: nil,
                diagram: nil
            ),
        ]
        let useCase = LoadDynamicUICardHistoryUseCase(repository: repository)

        let result = try await useCase.execute()

        #expect(result.map(\.id) == ["card-1"])
    }

    @Test func test_loadDynamicUICardHistory_fails_whenTheBackendIsUnreachable() async throws {
        let repository = StubDynamicCardHistoryRepository()
        repository.shouldFail = true
        let useCase = LoadDynamicUICardHistoryUseCase(repository: repository)

        await #expect(throws: DynamicUICardHistoryError.unavailable) {
            _ = try await useCase.execute()
        }
    }
}
