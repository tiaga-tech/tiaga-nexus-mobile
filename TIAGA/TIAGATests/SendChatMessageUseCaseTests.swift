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

    func observeTranscript() -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }

    func observeContextUsage() -> AsyncStream<ConversationContextUsage> {
        AsyncStream { $0.finish() }
    }

    var isStreaming: Bool { shouldBeStreaming }

    func resetConversation() async throws {}

    func fetchDynamicUICardHistory() async throws -> [DynamicUICard] { [] }
}

/// Thin purpose-built fake `AgentRosterRepository` for the agent-target
/// send tests — a single controllable agent, no fixture roster.
private final class StubAgentRosterRepository: AgentRosterRepository {
    var agent: Agent?

    func listAgents() async throws -> [Agent] {
        agent.map { [$0] } ?? []
    }

    func observeAgent(_ id: AgentIdentifier) -> AsyncStream<Agent> {
        AsyncStream { $0.finish() }
    }

    func cancelActiveTask(for id: AgentIdentifier) async throws {}

    func delete(_ id: AgentIdentifier) async throws {}
}

/// Thin purpose-built fake `AgentConversationRepository` for the
/// agent-target send tests.
private final class StubAgentConversationRepository: AgentConversationRepository {
    private(set) var sentTexts: [String] = []
    private(set) var sentAgentIDs: [AgentIdentifier] = []

    func send(_ text: String, to agentID: AgentIdentifier) async throws {
        sentTexts.append(text)
        sentAgentIDs.append(agentID)
    }

    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }
}

struct SendChatMessageUseCaseTests {

    @Test func test_sendChatMessage_succeeds_withNonEmptyText() async throws {
        let repository = StubConversationRepository()
        let useCase = SendChatMessageUseCase(orchestratorRepository: repository)

        try await useCase.execute(text: "  Build the landing page  ", to: .orchestrator)

        #expect(repository.sentTexts == ["Build the landing page"])
        #expect(repository.sentTargets == [.orchestrator])
    }

    @Test func test_sendChatMessage_fails_whenTextIsEmpty() async throws {
        let repository = StubConversationRepository()
        let useCase = SendChatMessageUseCase(orchestratorRepository: repository)

        await #expect(throws: SendChatMessageError.messageIsEmpty) {
            try await useCase.execute(text: "   \n\t  ", to: .orchestrator)
        }
        #expect(repository.sentTexts.isEmpty)
    }

    @Test func test_sendChatMessage_fails_whenConversationIsAlreadyStreaming() async throws {
        let repository = StubConversationRepository()
        repository.shouldBeStreaming = true
        let useCase = SendChatMessageUseCase(orchestratorRepository: repository)

        await #expect(throws: SendChatMessageError.conversationBusy) {
            try await useCase.execute(text: "Are we done yet?", to: .orchestrator)
        }
        #expect(repository.sentTexts.isEmpty)
    }

    @Test func test_sendChatMessage_succeeds_withNonEmptyText_toAgent() async throws {
        let agentID = AgentIdentifier(rawValue: "agent-nova")
        let agentRosterRepository = StubAgentRosterRepository()
        agentRosterRepository.agent = Agent(
            id: agentID,
            name: "Nova",
            state: .idle,
            pinnedDeviceID: DeviceIdentifier(rawValue: "device-1"),
            lastActivitySummary: "Waiting for the next instruction",
            lastActivityAt: Date(),
            contextUsageFraction: 0.1
        )
        let agentConversationRepository = StubAgentConversationRepository()
        let useCase = SendChatMessageUseCase(
            agentRosterRepository: agentRosterRepository,
            agentConversationRepository: agentConversationRepository
        )

        try await useCase.execute(text: "  Use the new hero image  ", to: .agent(agentID))

        #expect(agentConversationRepository.sentTexts == ["Use the new hero image"])
        #expect(agentConversationRepository.sentAgentIDs == [agentID])
    }

    @Test func test_sendChatMessage_fails_whenTargetAgentIsRunning() async throws {
        // A running agent is already mid-task and doesn't accept new input
        // until it's idle again — the only way to interrupt it is the stop
        // button, not a new message.
        let agentID = AgentIdentifier(rawValue: "agent-atlas")
        let agentRosterRepository = StubAgentRosterRepository()
        agentRosterRepository.agent = Agent(
            id: agentID,
            name: "Atlas",
            state: .running,
            pinnedDeviceID: DeviceIdentifier(rawValue: "device-1"),
            lastActivitySummary: "Redesigning the landing page",
            lastActivityAt: Date(),
            contextUsageFraction: 0.1
        )
        let agentConversationRepository = StubAgentConversationRepository()
        let useCase = SendChatMessageUseCase(
            agentRosterRepository: agentRosterRepository,
            agentConversationRepository: agentConversationRepository
        )

        await #expect(throws: SendChatMessageError.conversationBusy) {
            try await useCase.execute(text: "Any update?", to: .agent(agentID))
        }
        #expect(agentConversationRepository.sentTexts.isEmpty)
    }

    @Test func test_sendChatMessage_fails_whenTargetAgentIsCompacting() async throws {
        let agentID = AgentIdentifier(rawValue: "agent-comet")
        let agentRosterRepository = StubAgentRosterRepository()
        agentRosterRepository.agent = Agent(
            id: agentID,
            name: "Comet",
            state: .compacting,
            pinnedDeviceID: DeviceIdentifier(rawValue: "device-1"),
            lastActivitySummary: "Summarising history to free up context",
            lastActivityAt: Date(),
            contextUsageFraction: 0.97
        )
        let agentConversationRepository = StubAgentConversationRepository()
        let useCase = SendChatMessageUseCase(
            agentRosterRepository: agentRosterRepository,
            agentConversationRepository: agentConversationRepository
        )

        await #expect(throws: SendChatMessageError.conversationBusy) {
            try await useCase.execute(text: "Are we done yet?", to: .agent(agentID))
        }
        #expect(agentConversationRepository.sentTexts.isEmpty)
    }
}
