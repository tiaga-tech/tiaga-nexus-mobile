//
//  AgentConversationRepository.swift
//  TIAGA
//

import Foundation

/// One pinned agent's own direct conversation — separate from the
/// orchestrator's conversation (`OrchestratorConversationRepository`), since
/// an agent "has its own chat history" as its own domain concept (see
/// CLAUDE.md's `Agent` noun). Protocol only — see
/// `Data/Repositories/FakeAgentConversationRepository.swift` for the
/// (fixture-backed, no-network) implementation. Never call this directly
/// from a View; go through `SendChatMessageUseCase`.
protocol AgentConversationRepository {
    /// Adds an operator message to `agentID`'s conversation and produces a
    /// canned acknowledgment after a short artificial delay, mirroring the
    /// orchestrator conversation's honest busy-state exercise.
    func send(_ text: String, to agentID: AgentIdentifier) async throws

    /// The live transcript for one agent's conversation, chronologically
    /// ordered.
    func observeTranscript(for agentID: AgentIdentifier) -> AsyncStream<[ChatMessage]>

    /// Stops the agent's current task WITHOUT notifying the orchestrator, so
    /// the operator can take over via this direct chat — backs Agent Chat's
    /// stop button. A distinct real operation from
    /// `AgentRosterRepository.cancelActiveTask` (which DOES notify the
    /// orchestrator and is a fleet-wide "kill this task" action not
    /// currently exposed by any screen in this app): checked directly
    /// against the real backend's `AgentsController`/`OpenRouterLlmClient`
    /// — `POST /api/agents/{id}/cancel` vs. `POST /api/agents/{id}/interrupt`
    /// are genuinely different endpoints. Always succeeds if the agent
    /// exists — even calling this on an already-idle agent is a harmless
    /// no-op server-side, so unlike `CancelAgentTaskUseCase` there is no
    /// "nothing to interrupt" business error to throw.
    func interruptActiveTask(for agentID: AgentIdentifier) async throws

    /// Ends the direct-chat session and returns the agent to orchestrator
    /// control — called when the operator leaves Agent Chat. Fire-and-forget
    /// to match the real backend (`EndAgentChat` has no failure state the
    /// operator could act on).
    func endChat(with agentID: AgentIdentifier) async
}
