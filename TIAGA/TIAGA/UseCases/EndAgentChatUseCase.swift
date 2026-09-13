//
//  EndAgentChatUseCase.swift
//  TIAGA
//

import Foundation

/// Ends the operator's direct chat with an agent and hands it back to the
/// orchestrator, called when Agent Chat's screen closes.
///
/// Fire-and-forget by design, matching the real backend's `EndAgentChat`
/// (`POST /api/agents/{id}/handback`) — there is no failure state here the
/// operator could meaningfully act on.
struct EndAgentChatUseCase {
    let repository: AgentConversationRepository

    func execute(agentID: AgentIdentifier) async {
        await repository.endChat(with: agentID)
    }
}
