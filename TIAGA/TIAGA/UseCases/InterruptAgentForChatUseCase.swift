//
//  InterruptAgentForChatUseCase.swift
//  TIAGA
//

import Foundation

/// Takes over an agent's direct chat by stopping whatever task it's
/// currently running, backing Agent Chat's stop button.
///
/// This used to go through `CancelAgentTaskUseCase` (`POST
/// /api/agents/{id}/cancel`), which is actually the wrong real operation for
/// this button: checked `AgentsController.cs`/`OpenRouterLlmClient.cs`
/// directly, and `/cancel` notifies the orchestrator ("kill this task,
/// orchestrator is told"), while a direct-chat stop button needs `/interrupt`
/// ("take over for chat, don't nudge the orchestrator") — see
/// `AgentConversationRepository.interruptActiveTask`'s doc comment.
struct InterruptAgentForChatUseCase {
    let repository: AgentConversationRepository

    func execute(agentID: AgentIdentifier) async throws {
        try await repository.interruptActiveTask(for: agentID)
    }
}
