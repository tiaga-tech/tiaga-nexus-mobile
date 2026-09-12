//
//  AgentChatViewModel.swift
//  TIAGA
//

import Combine
import Foundation
import SwiftUI

/// Drives one agent's direct conversation: its own transcript, the agent's
/// live lifecycle state (to gate the composer and show/hide the stop
/// button), sending, cancelling its active task, and deleting it.
@MainActor
final class AgentChatViewModel: ObservableObject {
    let agentID: AgentIdentifier

    @Published private(set) var agent: Agent?
    @Published private(set) var transcript: [ChatMessage] = []
    @Published private(set) var sendErrorMessage: String?
    @Published private(set) var cancelErrorMessage: String?
    @Published private(set) var deleteErrorMessage: String?
    /// Flips true once `delete()` succeeds — the View observes this to pop
    /// back out of the now-gone agent's screen.
    @Published private(set) var isDeleted = false

    @Published var composerText = ""

    private let sendUseCase: SendChatMessageUseCase
    private let cancelUseCase: CancelAgentTaskUseCase
    private let deleteUseCase: DeleteAgentUseCase
    private let agentRosterRepository: AgentRosterRepository
    private let agentConversationRepository: AgentConversationRepository

    init(
        agentID: AgentIdentifier,
        agentRosterRepository: AgentRosterRepository = FakeAgentRosterRepository(),
        agentConversationRepository: AgentConversationRepository = FakeAgentConversationRepository()
    ) {
        self.agentID = agentID
        self.agentRosterRepository = agentRosterRepository
        self.agentConversationRepository = agentConversationRepository
        self.sendUseCase = SendChatMessageUseCase(
            agentRosterRepository: agentRosterRepository,
            agentConversationRepository: agentConversationRepository
        )
        self.cancelUseCase = CancelAgentTaskUseCase(repository: agentRosterRepository)
        self.deleteUseCase = DeleteAgentUseCase(repository: agentRosterRepository)
        startObserving()
    }

    /// The stop button only makes sense while there's an active task the
    /// operator can actually interrupt. A `.compacting` agent has an active
    /// operation too, but per `AgentState.compacting`'s own business rule
    /// it's a self-contained transition that must finish on its own.
    var canCancelActiveTask: Bool {
        agent?.state == .running
    }

    /// Mirrors `SendChatMessageUseCase`'s own busy check so the composer
    /// visibly reflects it, rather than only surfacing the rule as an error
    /// after a failed send attempt. A running agent is already mid-task and
    /// doesn't accept new input until it's idle again (or has errored) — the
    /// operator's only way to interrupt it is the stop button.
    var isComposerDisabled: Bool {
        agent?.state == .running || agent?.state == .compacting
    }

    func send() async {
        guard !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        sendErrorMessage = nil
        do {
            let text = composerText
            composerText = ""
            try await sendUseCase.execute(text: text, to: .agent(agentID))
        } catch let error as SendChatMessageError {
            sendErrorMessage = error.errorDescription
        } catch let error as AgentLifecycleError {
            sendErrorMessage = error.errorDescription
        } catch {
            sendErrorMessage = SendChatMessageError.conversationBusy.errorDescription
        }
    }

    func cancelActiveTask() async {
        cancelErrorMessage = nil
        do {
            try await cancelUseCase.execute(agentID: agentID)
        } catch let error as AgentLifecycleError {
            cancelErrorMessage = error.errorDescription
        } catch {
            cancelErrorMessage = AgentLifecycleError.noActiveTaskToCancel.errorDescription
        }
    }

    func delete() async {
        deleteErrorMessage = nil
        do {
            try await deleteUseCase.execute(agentID: agentID)
            isDeleted = true
        } catch let error as AgentLifecycleError {
            deleteErrorMessage = error.errorDescription
        } catch {
            deleteErrorMessage = AgentLifecycleError.agentNoLongerExists.errorDescription
        }
    }

    private func startObserving() {
        let agentStream = agentRosterRepository.observeAgent(agentID)
        let transcriptStream = agentConversationRepository.observeTranscript(for: agentID)

        Task { [weak self] in
            for await agent in agentStream {
                self?.agent = agent
            }
        }

        Task { [weak self] in
            for await entries in transcriptStream {
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.transcript = entries
                }
            }
        }
    }
}
