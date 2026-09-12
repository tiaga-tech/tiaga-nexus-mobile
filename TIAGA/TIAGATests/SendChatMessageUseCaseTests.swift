//
//  SendChatMessageUseCaseTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Thin purpose-built fake for `SendChatMessageUseCase` — one controllable
/// busy flag, no artificial delays, no fixture transcript.
private final class StubConversationRepository: OrchestratorConversationRepository {
    var shouldBeStreaming = false
    private(set) var sentTexts: [String] = []
    private(set) var sentTargets: [ConversationTarget] = []

    func send(_ text: String, to target: ConversationTarget) async throws {
        sentTexts.append(text)
        sentTargets.append(target)
    }

    func observeTranscript() -> AsyncStream<[TranscriptEntry]> {
        AsyncStream { $0.finish() }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        AsyncStream { $0.finish() }
    }

    var isStreaming: Bool { shouldBeStreaming }

    func resetConversation() async throws {}

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] { [] }
}

struct SendChatMessageUseCaseTests {

    @Test func test_sendChatMessage_succeeds_withNonEmptyText() async throws {
        let repository = StubConversationRepository()
        let useCase = SendChatMessageUseCase(repository: repository)

        try await useCase.execute(text: "  Build the landing page  ", to: .orchestrator)

        #expect(repository.sentTexts == ["Build the landing page"])
        #expect(repository.sentTargets == [.orchestrator])
    }

    @Test func test_sendChatMessage_fails_whenTextIsEmpty() async throws {
        let repository = StubConversationRepository()
        let useCase = SendChatMessageUseCase(repository: repository)

        await #expect(throws: SendChatMessageError.messageIsEmpty) {
            try await useCase.execute(text: "   \n\t  ", to: .orchestrator)
        }
        #expect(repository.sentTexts.isEmpty)
    }

    @Test func test_sendChatMessage_fails_whenConversationIsAlreadyStreaming() async throws {
        let repository = StubConversationRepository()
        repository.shouldBeStreaming = true
        let useCase = SendChatMessageUseCase(repository: repository)

        await #expect(throws: SendChatMessageError.conversationBusy) {
            try await useCase.execute(text: "Are we done yet?", to: .orchestrator)
        }
        #expect(repository.sentTexts.isEmpty)
    }
}
