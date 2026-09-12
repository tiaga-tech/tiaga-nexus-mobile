//
//  SendChatMessageUseCase.swift
//  TIAGA
//

import Foundation

/// Sends a text message to a conversation target.
///
/// Reusable for both the orchestrator chat and Agent Chat — the "text can't
/// be empty" rule is identical for both, but what counts as "busy" differs:
/// the orchestrator conversation tracks its own streaming-reply flag, while
/// an agent's own conversation is gated by the agent's own lifecycle state
/// instead — an agent doesn't stream a single synchronous reply the way the
/// orchestrator does. A `.running` agent is already mid-task and doesn't
/// accept new input until it's idle again (the operator's only way to
/// interrupt it is the stop button, not a new message), and `.compacting`
/// is blocked per `AgentState.compacting`'s own business rule.
///
/// Each screen only supplies the dependency it actually uses: `ChatViewModel`
/// passes `orchestratorRepository`; `AgentChatViewModel` passes
/// `agentRosterRepository` + `agentConversationRepository`. The unused side's
/// default is a harmless, never-invoked fake — see each `case` below.
///
/// Business Rules:
/// 1. The text cannot be empty or whitespace-only.
/// 2. Sending to `.orchestrator` fails while it's still streaming a reply.
/// 3. Sending to `.agent` fails while that agent is `.running` or `.compacting`.
struct SendChatMessageUseCase {
    let orchestratorRepository: OrchestratorConversationRepository
    let agentRosterRepository: AgentRosterRepository
    let agentConversationRepository: AgentConversationRepository

    init(
        orchestratorRepository: OrchestratorConversationRepository = FakeOrchestratorConversationRepository(),
        agentRosterRepository: AgentRosterRepository = FakeAgentRosterRepository(),
        agentConversationRepository: AgentConversationRepository = FakeAgentConversationRepository()
    ) {
        self.orchestratorRepository = orchestratorRepository
        self.agentRosterRepository = agentRosterRepository
        self.agentConversationRepository = agentConversationRepository
    }

    func execute(text: String, to target: ConversationTarget) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SendChatMessageError.messageIsEmpty
        }

        switch target {
        case .orchestrator:
            guard !orchestratorRepository.isStreaming else {
                throw SendChatMessageError.conversationBusy
            }
            try await orchestratorRepository.send(trimmed, to: target)

        case .agent(let agentID):
            let agents = try await agentRosterRepository.listAgents()
            guard let agent = agents.first(where: { $0.id == agentID }) else {
                throw AgentLifecycleError.agentNoLongerExists
            }
            switch agent.state {
            case .idle, .error:
                try await agentConversationRepository.send(trimmed, to: agentID)
            case .running, .compacting:
                throw SendChatMessageError.conversationBusy
            }
        }
    }
}
